import os
import json
import time
import traceback
import requests

from strands import Agent
from strands.tools.mcp import MCPClient
from mcp import stdio_client, StdioServerParameters

from ssm_secrets import get_secret

# =========================
# Global (warm reuse cache)
# =========================
_mcp_client = None
_tools = None
_agent = None
_last_init_ts = 0

SYSTEM_PROMPT = """あなたはお店検索アシスタントです。
ユーザーの要望（場所・ジャンル・予算・時間帯・人数・雰囲気）を不足があれば質問して確認し、
Google Maps の情報を使って候補を提案してください。
日本語で丁寧に、箇条書きで分かりやすく返答してください。
Markdown記法（#, *, -, >, ``` など）は一切使用しないでください。
回答内は全て改行してください。
"""

def _get_google_maps_mcp_client():
    api_key = get_secret("GOOGLE_MAPS_API_KEY")
    if not api_key:
        raise RuntimeError("GOOGLE_MAPS_API_KEY is required")

    env = os.environ.copy()
    env["GOOGLE_MAPS_API_KEY"] = api_key

    return MCPClient(lambda: stdio_client(
        StdioServerParameters(
            command="node",
            args=["/var/task/node_modules/@modelcontextprotocol/server-google-maps/dist/index.js"],
            env=env
        )
    ))

def _ensure_agent_ready(force_reinit: bool = False):
    global _mcp_client, _tools, _agent, _last_init_ts

    REINIT_EVERY_SEC = int(os.environ.get("REINIT_EVERY_SEC", "900"))
    now = time.time()
    if (not force_reinit) and _agent is not None and (now - _last_init_ts) < REINIT_EVERY_SEC:
        return

    try:
        if _mcp_client is not None:
            _mcp_client.stop()
    except Exception:
        pass

    print("[DEBUG] Initializing MCP client / tools / agent ...")

    _mcp_client = _get_google_maps_mcp_client()
    _mcp_client.start()
    _tools = _mcp_client.list_tools_sync()

    _agent = Agent(
        tools=_tools,
        system_prompt=SYSTEM_PROMPT
    )

    _last_init_ts = now

def _call_agent(user_text: str) -> str:
    _ensure_agent_ready()

    prompt = f"""ユーザーの依頼:
{user_text}

出力フォーマット:
- 店名
- 距離(目安)
- 価格帯(目安)
- おすすめポイント(1つ)
- googlemap上のリンク
を3件
- 最後に「もっと絞り込む質問」を1〜2個
googlemap上のリンクは以下の形式で出力してください。
https://www.google.com/maps/place/?q=place_id:PLACE_ID
"""
    return str(_agent(prompt))

# =========================
# LINE senders
# =========================
def send_line_reply(reply_token, message, access_token):
    url = "https://api.line.me/v2/bot/message/reply"
    header = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {access_token}"
    }

    MAX_LEN = int(os.environ.get("LINE_MAX_TEXT_LEN", "4500"))
    if len(message) > MAX_LEN:
        message = message[:MAX_LEN - 20] + "\n...(長いので省略)"

    body = json.dumps({
        "replyToken": reply_token,
        "messages": [{"type": "text", "text": message}]
    })

    res = requests.post(url=url, headers=header, data=body, timeout=10)
    print(f"[DEBUG] LINE REPLY status: {res.status_code}")
    if res.status_code >= 300:
        print(f"[DEBUG] LINE REPLY response: {res.text}")
    return res

def send_line_push(to_id, message, access_token):
    """
    to_id は userId / groupId / roomId のいずれでもOK
    """
    url = "https://api.line.me/v2/bot/message/push"
    header = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {access_token}"
    }

    MAX_LEN = int(os.environ.get("LINE_MAX_TEXT_LEN", "4500"))
    if len(message) > MAX_LEN:
        message = message[:MAX_LEN - 20] + "\n...(長いので省略)"

    body = json.dumps({
        "to": to_id,
        "messages": [{"type": "text", "text": message}]
    })

    res = requests.post(url=url, headers=header, data=body, timeout=10)
    print(f"[DEBUG] LINE PUSH status: {res.status_code}")
    if res.status_code >= 300:
        print(f"[DEBUG] LINE PUSH response: {res.text}")
    return res

def _get_push_destination(ev) -> str | None:
    """
    返信先を、個チャ/グループ/ルームで切り替える。
    """
    source = ev.get("source", {}) or {}
    source_type = source.get("type")

    if source_type == "user":
        return source.get("userId")
    if source_type == "group":
        return source.get("groupId")
    if source_type == "room":
        return source.get("roomId")
    return None

# =========================
# LINE webhook handler
# =========================
def lambda_handler(event, context):
    print("=== Lambda handler started ===")
    print(f"Event: {event}")

    CHANNEL_ACCESS_TOKEN = get_secret("CHANNEL_ACCESS_TOKEN")
    if not CHANNEL_ACCESS_TOKEN:
        print("[ERROR] CHANNEL_ACCESS_TOKEN is missing")
        return {"statusCode": 500, "body": "CHANNEL_ACCESS_TOKEN is missing"}

    try:
        body_str = event.get("body") or ""
        if event.get("isBase64Encoded"):
            import base64
            body_str = base64.b64decode(body_str).decode("utf-8")

        body = json.loads(body_str) if body_str else {}
        print(f"Parsed body: {body}")
    except Exception as e:
        print(f"[ERROR] Error parsing body: {e}")
        return {"statusCode": 400, "body": "Invalid body"}

    if not body.get("events"):
        print("No events in body, returning OK")
        return {"statusCode": 200, "body": "OK"}

    for ev in body["events"]:
        try:
            if ev.get("type") != "message":
                continue
            msg = ev.get("message", {})
            if msg.get("type") != "text":
                continue

            reply_token = ev.get("replyToken")
            received_text = (msg.get("text", "") or "").strip()
            source = ev.get("source", {}) or {}
            source_type = source.get("type")
            print(f"[DEBUG] replyToken: {reply_token}")
            print(f"[DEBUG] receivedText: {received_text}")
            print(f"[DEBUG] sourceType: {source_type}")

            # トリガー判定: 個人チャットは全て反応、グループ/ルームは@お店で反応
            TRIGGERS = ["@お店", "＠お店"]  # 半角・全角両対応
            
            if source_type == "user":
                # 個人チャット: 全てのメッセージに反応
                query = received_text
            else:
                # グループ/ルーム: @お店 または ＠お店 で始まる場合のみ反応
                matched_trigger = None
                for trigger in TRIGGERS:
                    if received_text.startswith(trigger):
                        matched_trigger = trigger
                        break
                
                if not matched_trigger:
                    print("[DEBUG] trigger not matched in group/room, ignoring")
                    continue
                
                # トリガー文字列の後ろをクエリにする
                query = received_text[len(matched_trigger):].strip()
            
            if not query:
                if reply_token:
                    if source_type == "user":
                        send_line_reply(
                            reply_token,
                            "条件を教えてください。\n例）上野で静かなカフェ\n例）渋谷でデート向き居酒屋",
                            CHANNEL_ACCESS_TOKEN
                        )
                    else:
                        send_line_reply(
                            reply_token,
                            "使い方：@お店 の後に条件を書いてね。\n例）@お店 上野で静かなカフェ\n例）@お店 渋谷でデート向き居酒屋",
                            CHANNEL_ACCESS_TOKEN
                        )
                continue

            # ① まず即レス（reply）: 「反応してる」ことを見せる
            if reply_token:
                send_line_reply(
                    reply_token,
                    "ただいま条件に合うお店をお探ししております。検索結果のご案内まで、少々お待ちください。",
                    CHANNEL_ACCESS_TOKEN
                )

            # ② 重い処理（Agent）
            try:
                ai_response = _call_agent(query)
            except Exception as e:
                print(f"[ERROR] Agent error: {type(e).__name__}: {e}")
                traceback.print_exc()

                # 一回だけ強制再初期化してリトライ
                try:
                    print("[DEBUG] Retrying with force re-init...")
                    _ensure_agent_ready(force_reinit=True)
                    ai_response = _call_agent(query)
                except Exception as e2:
                    print(f"[ERROR] Retry failed: {type(e2).__name__}: {e2}")
                    traceback.print_exc()
                    ai_response = "申し訳ございません。現在検索サービスに接続できません。少し時間をおいて再度お試しください。"

            # ③ 結果は push（個チャ/グループ/ルームに対応）
            dest = _get_push_destination(ev)
            if dest:
                send_line_push(dest, ai_response, CHANNEL_ACCESS_TOKEN)
            else:
                print("[WARN] push destination not found; cannot push result")

        except Exception as e:
            print(f"[ERROR] Unexpected event handling error: {e}")
            traceback.print_exc()

    print("=== Lambda handler completed ===")
    return {"statusCode": 200, "body": "OK"}
