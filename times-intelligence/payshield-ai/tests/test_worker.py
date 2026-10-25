from app.messaging.worker import parse


def test_parse_valid_and_invalid_bodies():
    good = '{"tenantUid":"11111111-1111-4111-8111-111111111111","companyUid":"aaaaaaa1-0000-4000-8000-000000000001",' \
           '"payRunUid":"bbbbbbb1-0000-4000-8000-000000000001","fingerprint":"x"}'
    assert parse(good)["fingerprint"] == "x"
    assert parse("not json") is None
    assert parse('{"tenantUid":"x","companyUid":"y","payRunUid":"z"}') is None
    assert parse('{"tenantUid":"11111111-1111-4111-8111-111111111111"}') is None
