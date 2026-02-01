"""Google Maps APIをGatewayターゲットとして追加"""
import boto3
import json

# 設定
REGION = "ap-northeast-1"
GATEWAY_ID = "lineshopbot-gateway-7muytof3dt"
CRED_PROVIDER_ARN = "arn:aws:bedrock-agentcore:ap-northeast-1:179323781340:token-vault/default/apikeycredentialprovider/google-maps-api-key"

# OpenAPI仕様を読み込み
with open("google_maps_openapi.json", "r") as f:
    openapi_spec = json.load(f)

# boto3クライアント
client = boto3.client("bedrock-agentcore-control", region_name=REGION)

# Gateway Targetを作成
print("Creating gateway target...")
target_response = client.create_gateway_target(
    gatewayIdentifier=GATEWAY_ID,
    name="GoogleMapsPlaces",
    targetConfiguration={
        "mcp": {
            "openApiSchema": {
                "inlinePayload": json.dumps(openapi_spec)
            }
        }
    },
    credentialProviderConfigurations=[
        {
            "credentialProviderType": "API_KEY",
            "credentialProvider": {
                "apiKeyCredentialProvider": {
                    "providerArn": CRED_PROVIDER_ARN,
                    "credentialParameterName": "key",
                    "credentialLocation": "QUERY_PARAMETER"
                }
            }
        }
    ]
)

print(f"\n✅ Target created!")
print(f"Target ID: {target_response.get('targetId')}")
print(f"Status: {target_response.get('status')}")
