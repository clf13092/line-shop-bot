"""お店検索エージェント - AgentCore Gateway + Memory"""
import os
import boto3
import base64
import requests
from strands import Agent
from strands.models import BedrockModel
from strands.tools.mcp import MCPClient
from mcp.client.streamable_http import streamablehttp_client
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from bedrock_agentcore.memory import MemorySessionManager

app = BedrockAgentCoreApp()

# 設定
REGION = os.environ.get("AWS_REGION", "ap-northeast-1")
GATEWAY_URL = "https://lineshopbot-gateway-7muytof3dt.gateway.bedrock-agentcore.ap-northeast-1.amazonaws.com/mcp"
COGNITO_USER_POOL_ID = "ap-northeast-1_HvOohBGUD"
COGNITO_CLIENT_ID = "2886as738t54dap6r7qg4qr537"
COGNITO_DOMAIN = "agentcore-e2e69553"
MEMORY_ID = "lineshopbot_memory-zr368iC1Qc"
SSM_PROMPT_KEY = "/line-shop-bot/dev/AGENT_SYSTEM_PROMPT"

DEFAULT_SYSTEM_PROMPT = """あなたはお店検索アシスタントです。
ユーザーの要望（場所・ジャンル・雰囲気など）を確認し、Google Mapsの情報を使って候補を3件提案してください。
日本語で丁寧に回答してください。Markdown記法は使用しないでください。
"""

def get_system_prompt():
    """SSMからシステムプロンプトを取得"""
    try:
        ssm = boto3.client('ssm', region_name=REGION)
        response = ssm.get_parameter(Name=SSM_PROMPT_KEY)
        return response['Parameter']['Value']
    except Exception as e:
        print(f"[WARN] Failed to get prompt from SSM: {e}")
        return DEFAULT_SYSTEM_PROMPT

def get_access_token():
    """Cognitoからアクセストークンを取得"""
    idp = boto3.client('cognito-idp', region_name=REGION)
    client_info = idp.describe_user_pool_client(
        UserPoolId=COGNITO_USER_POOL_ID,
        ClientId=COGNITO_CLIENT_ID
    )
    client_secret = client_info['UserPoolClient']['ClientSecret']
    
    auth_string = base64.b64encode(f'{COGNITO_CLIENT_ID}:{client_secret}'.encode()).decode()
    token_url = f'https://{COGNITO_DOMAIN}.auth.{REGION}.amazoncognito.com/oauth2/token'
    
    response = requests.post(
        token_url,
        headers={
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': f'Basic {auth_string}'
        },
        data={
            'grant_type': 'client_credentials',
            'scope': 'lineshopbot-gateway/invoke'
        },
        timeout=10
    )
    response.raise_for_status()
    return response.json()['access_token']

def create_mcp_transport(gateway_url: str, access_token: str):
    return streamablehttp_client(gateway_url, headers={"Authorization": f"Bearer {access_token}"})

@app.entrypoint
async def invoke(payload, context):
    """エージェントのエントリーポイント"""
    user_message = payload.get("prompt", payload.get("message", ""))
    user_id = payload.get("user_id", "default_user")
    
    if not user_message:
        yield "メッセージを入力してください。"
        return
    
    # Memory セッション管理
    memory_manager = MemorySessionManager(memory_id=MEMORY_ID, region_name=REGION)
    session = memory_manager.create_memory_session(
        actor_id=user_id,
        session_id=f"{user_id}_session"
    )
    
    # 過去の会話履歴を取得
    past_turns = session.get_last_k_turns(k=10)
    conversation_history = ""
    if past_turns:
        conversation_history = "\n\n過去の会話:\n"
        for turn in past_turns:
            conversation_history += f"- {turn}\n"
    
    # アクセストークン取得
    access_token = get_access_token()
    
    # MCPクライアント設定
    mcp_client = MCPClient(lambda: create_mcp_transport(GATEWAY_URL, access_token))
    
    # モデル設定
    model = BedrockModel(
        model_id="global.anthropic.claude-sonnet-4-5-20250929-v1:0",
        region_name=REGION
    )
    
    with mcp_client:
        tools = mcp_client.list_tools_sync()
        
        agent = Agent(
            model=model,
            system_prompt=get_system_prompt() + conversation_history,
            tools=tools
        )
        
        result = agent(user_message)
        response_text = str(result)
        
        # 会話をMemoryに保存
        from bedrock_agentcore.memory.constants import ConversationalMessage, MessageRole
        session.add_turns(messages=[
            ConversationalMessage(user_message, MessageRole.USER)
        ])
        session.add_turns(messages=[
            ConversationalMessage(response_text, MessageRole.ASSISTANT)
        ])
        
        yield response_text

if __name__ == "__main__":
    app.run()
