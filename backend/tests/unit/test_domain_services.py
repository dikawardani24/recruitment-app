from __future__ import annotations

from app.domain.services import SkillNormalizer, YearsExperienceCalculator


def test_skill_normalizer_canonicalizes_aliases():
    normalizer = SkillNormalizer()
    out = normalizer.normalize(["Docker", "docker", "Kubernetes", "k8s", "React.js"])
    assert out == ["docker", "kubernetes", "react"]


def test_skill_normalizer_dedupes():
    normalizer = SkillNormalizer()
    assert normalizer.normalize(["Dart", "dart", "Dart"]) == ["dart"]


def test_years_calculator_total():
    from app.domain.entities import DateRange

    calc = YearsExperienceCalculator()
    total = calc.total_years([DateRange("2020-03", "2024-06"), DateRange("2016-01", "2019-12")])
    assert total == 8.17


def test_fast_progression():
    calc = YearsExperienceCalculator()
    assert calc.fast_progression(["Junior Developer", "Software Engineer", "Senior Engineer"])
    assert not calc.fast_progression(["Senior Engineer", "Software Engineer", "Junior Developer"])
