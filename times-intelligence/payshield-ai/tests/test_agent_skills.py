"""Matching new questions to what the agent was taught (word overlap, no LLM)."""

from __future__ import annotations

from app.services.agent_skills import MATCH_AT, similarity, words


def test_words_drop_stop_words_and_map_synonyms():
    assert words("Who are the big earners in our staff?") == ["highest", "pay", "employee"]


def test_rephrased_question_matches():
    assert similarity("Who are the big earners?", "show me the biggest earners") >= MATCH_AT
    assert similarity("What is our maternity leave policy", "maternity leave policy?") >= MATCH_AT


def test_unrelated_question_does_not_match():
    assert similarity("maternity leave policy", "who has unusual overtime") < MATCH_AT
    assert similarity("", "anything") == 0.0
