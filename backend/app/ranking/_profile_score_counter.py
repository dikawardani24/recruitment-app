from app.config import Settings
from app.extraction import Profile
from app.ranking._requirements import Requirements, KNOWN_EDUCATION_LEVELS

class ProfileScoreCounter:
    def __init__(self, profile: Profile, requirements: Requirements, settings: Settings):
        self.profile = profile
        self.requirement = requirements
        self.settings = settings

    def __score_req_skills(self, total_matched_req: int, total_req: int, total_matched_pref: int,  total_pref: list):
        score_req = 0.7 * (total_matched_req / total_req)
        score_pref = 0.3 * (total_matched_pref / total_pref if total_pref > 0 else 0.0)
        return score_req + score_pref
    
    def __score_pref_skills(self, total_matched_pref: int, total_pref: list):
        return 0.5 + 0.5 * (total_matched_pref / total_pref)
        
    def count_skill_score(self):
        req_skills = self.requirement.req_skills
        pref_skills = self.requirement.pref_skills
        matched_req = self.requirement.matched_req(self.profile)
        matched_pref = self.requirement.matched_pref(self.profile)

        total_matched_req = len(matched_req)
        total_req = len(req_skills)
        total_matched_pref = len(matched_pref) 
        total_pref = len(pref_skills)
        
        if req_skills:
            return self.__score_req_skills(total_matched_req= total_matched_req, total_req= total_req, total_matched_pref=total_matched_pref, total_pref=total_pref)
        if pref_skills:
            return self.__score_pref_skills(total_pref=total_pref, total_matched_pref=total_matched_pref)

        return 0.5 if self.profile.skills else 0.2
    
    def count_experience_score(self):
        min_years = self.requirement.min_years
        years_experience = self.profile.years_experience
        
        if min_years > 0:
            return min(1.0, years_experience / min_years)
                
        return 0.7 if years_experience > 0 else 0.4
    
    def count_edu_score(self):
        req_edu = self.requirement.req_edu

        if req_edu:
            requirement_level = KNOWN_EDUCATION_LEVELS.get(req_edu, 0)
            return min(
                1.0, KNOWN_EDUCATION_LEVELS.get(self.profile.education or "", 0) / max(1, requirement_level)
            )
        return 0.8 if self.profile.education else 0.5
    
    def count_cert_score(self):
        req_certs = self.requirement.req_certs or []
        certifications = self.profile.certifications
        profile_certs = {c.lower() for c in certifications}
        matched_certs = [c for c in req_certs if c.lower() in profile_certs]

        if req_certs:
            return len(matched_certs) / len(req_certs)
        return 0.7 if certifications else 0.5
        