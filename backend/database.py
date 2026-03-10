import os
from supabase import create_client, Client
from dotenv import load_dotenv
from logger import get_logger

load_dotenv()

logger = get_logger(__name__)

_url: str = os.environ.get("SUPABASE_URL", "")
_key: str = os.environ.get("SUPABASE_KEY", "")

_client: Client | None = None


def get_supabase_client() -> Client | None:
    global _client
    if _client is not None:
        return _client
    if not _url or not _key:
        logger.warning("SUPABASE_URL 또는 SUPABASE_KEY가 설정되지 않았습니다.")
        return None
    _client = create_client(_url, _key)
    return _client
