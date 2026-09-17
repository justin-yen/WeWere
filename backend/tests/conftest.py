import os
import sys
from pathlib import Path

# Never read production credentials or contact a real project in this suite.
os.environ.update(SUPABASE_URL='https://unit-test.supabase.co', SUPABASE_ANON_KEY='test-anon', SUPABASE_SERVICE_ROLE_KEY='test-service', SUPABASE_JWT_SECRET='test-signing-secret', APP_ENV='production', ENABLE_TEST_ENDPOINTS='false', INTERNAL_API_KEY='')
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
