"""
Parameter Storeからシークレットを取得するモジュール。

要件:
- 4.1: コールドスタート時にboto3を使用してParameter_Storeクライアントを初期化
- 4.2: ウォーム起動中、取得したシークレットをメモリにキャッシュ
- 4.4: 環境変数フォールバック（ローカルテスト用）
"""

import os
import boto3

_ssm_client = None
_secrets_cache = {}


def _get_ssm_client():
    """SSMクライアントを取得（遅延初期化）"""
    global _ssm_client
    if _ssm_client is None:
        _ssm_client = boto3.client('ssm')
    return _ssm_client


def get_secret(name: str, use_cache: bool = True) -> str:
    """
    Parameter Storeからシークレットを取得する。
    
    環境変数SSM_PREFIXが設定されている場合はParameter Storeから取得。
    設定されていない場合は環境変数から取得（ローカルテスト用）。
    
    Args:
        name: シークレット名（例: GOOGLE_MAPS_API_KEY）
        use_cache: キャッシュを使用するかどうか（デフォルト: True）
    
    Returns:
        シークレットの値
    
    Raises:
        RuntimeError: シークレットが見つからない場合
    """
    ssm_prefix = os.environ.get("SSM_PREFIX")
    
    # ローカルテスト用：SSM_PREFIXがない場合は環境変数から取得
    if not ssm_prefix:
        return os.environ.get(name, "")
    
    # キャッシュチェック
    if use_cache and name in _secrets_cache:
        return _secrets_cache[name]
    
    # Parameter Storeから取得
    try:
        client = _get_ssm_client()
        param_name = f"{ssm_prefix}/{name}"
        response = client.get_parameter(Name=param_name, WithDecryption=True)
        value = response['Parameter']['Value']
        
        if use_cache:
            _secrets_cache[name] = value
        
        return value
    except Exception as e:
        print(f"[ERROR] Failed to get secret {name}: {e}")
        # フォールバック：環境変数から取得を試みる
        fallback = os.environ.get(name, "")
        if fallback:
            print(f"[WARN] Using environment variable fallback for {name}")
            return fallback
        raise RuntimeError(f"Secret {name} not found in Parameter Store or environment")


def clear_cache():
    """キャッシュをクリアする（テスト用）"""
    global _secrets_cache
    _secrets_cache = {}
