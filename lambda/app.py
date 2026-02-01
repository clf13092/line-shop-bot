import os
import json
import traceback
import requests
import boto3

from ssm_secrets import get_secret

# AgentCore Runtime設定
AGENT_RUNTIME_ARN = "arn:aws:bedrock-agentcore:ap-northeast-1:179323781340:runtime/lineshopbot_Agent-bO1T7aE4xR"
REGION = "ap-northeast-1"

def _call_agentcore(user_id: str, query: str) -> str:
    """AgentCore Runtimeを呼び出す"""
    client = boto3.client("bedrock-agentcore", region_name=REGION)
    
    response = client.invoke_agent_runtime(
        agentRuntimeArn=AGENT_RUNTIME_ARN,
        payload=json.dumps({
            "prompt": query,
            "user_id": user_id
        }),
        contentType="application/json"
    )
    
    # StreamingBodyから読み取る（キーは'response'）
    body = response.get("response")
    if body and hasattr(body, 'read'):
        result = body.read().decode("utf-8")
    else:
        result = ""
    
    # SSE形式 "data: \"...\"\n" からテキストを抽出
    if result.startswith('data: "'):
        result = result[7:]
        if result.endswith('"\n'):
            result = result[:-2]
        result = result.replace("\\n", "\n")
    
    return result if result else "申し訳ございません。応答を取得できませんでした。"

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
    return res

def send_line_push(to_id, message, access_token):
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
    print(f"[DEBUG] LINE PUSH status: {res.status_code}, body: {res.text}")
    return res

def _get_push_destination(ev) -> str | None:
    source = ev.get("source", {}) or {}
    source_type = source.get("type")
    if source_type == "user":
        return source.get("userId")
    if source_type == "group":
        return source.get("groupId")
    if source_type == "room":
        return source.get("roomId")
    return None

def _get_user_id(ev) -> str:
    """ユーザーIDを取得（Memory用）"""
    source = ev.get("source", {}) or {}
    return source.get("userId") or source.get("groupId") or source.get("roomId") or "unknown"

# =========================
# LINE webhook handler
# =========================
def lambda_handler(event, context):
    print("=== Lambda handler started ===")

    CHANNEL_ACCESS_TOKEN = get_secret("CHANNEL_ACCESS_TOKEN")
    if not CHANNEL_ACCESS_TOKEN:
        return {"statusCode": 500, "body": "CHANNEL_ACCESS_TOKEN is missing"}

    try:
        body_str = event.get("body") or ""
        if event.get("isBase64Encoded"):
            import base64
            body_str = base64.b64decode(body_str).decode("utf-8")
        body = json.loads(body_str) if body_str else {}
    except Exception as e:
        print(f"[ERROR] Error parsing body: {e}")
        return {"statusCode": 400, "body": "Invalid body"}

    if not body.get("events"):
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
            user_id = _get_user_id(ev)

            # トリガー判定
            TRIGGERS = ["@お店", "＠お店"]
            
            if source_type == "user":
                query = received_text
            else:
                matched_trigger = None
                for trigger in TRIGGERS:
                    if received_text.startswith(trigger):
                        matched_trigger = trigger
                        break
                if not matched_trigger:
                    continue
                query = received_text[len(matched_trigger):].strip()
            
            if not query:
                if reply_token:
                    msg = "条件を教えてください。\n例）上野で静かなカフェ" if source_type == "user" else "使い方：@お店 の後に条件を書いてね。"
                    send_line_reply(reply_token, msg, CHANNEL_ACCESS_TOKEN)
                continue

            # 即レス
            if reply_token:
                send_line_reply(reply_token, "ただいまお店をお探ししております。少々お待ちください。", CHANNEL_ACCESS_TOKEN)

            # AgentCore Runtime呼び出し
            try:
                ai_response = _call_agentcore(user_id, query)
            except Exception as e:
                print(f"[ERROR] AgentCore error: {e}")
                traceback.print_exc()
                ai_response = "申し訳ございません。現在検索サービスに接続できません。"

            # 結果をpush
            dest = _get_push_destination(ev)
            if dest:
                send_line_push(dest, ai_response, CHANNEL_ACCESS_TOKEN)

        except Exception as e:
            print(f"[ERROR] Event handling error: {e}")
            traceback.print_exc()

    return {"statusCode": 200, "body": "OK"}
