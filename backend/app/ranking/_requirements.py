from app.config import Settings
from app.extraction import Profile

KNOWN_EDUCATION_LEVELS = {"": 0, "diploma": 1, "bsc": 2, "msc": 3, "phd": 4}

class Requirements:
    def __init__(self, requirements: dict):
        self.req_skills = requirements.get("required_skills") or []
        self.pref_skills = requirements.get("preferred_skills") or []
        self.min_years = float(requirements.get("min_years") or 0.0)
        self.req_edu = requirements.get("education")
        self.req_certs = requirements.get("certifications") or []
        pass
    
    def __profile_skills(self, profile: Profile):
        return {s.lower() for s in profile.skills}
    
    def matched_req(self, profile: Profile):
        profile_skills = self.__profile_skills(profile)
        return [s for s in self.req_skills if s.lower() in profile_skills]
    
    def matched_pref(self, profile: Profile):
        profile_skills = self.__profile_skills(profile)
        return [s for s in self.pref_skills if s.lower() in profile_skills]
        
    def matched_certs(self, profile: Profile):
        profile_certs = {c.lower() for c in profile.certifications}
        return [c for c in self.req_certs if c.lower() in profile_certs]
    
    def missing_skill(self, profile: Profile):
        profile_skills = self.__profile_skills(profile)
        return [s for s in self.req_skills if s.lower() not in profile_skills]
