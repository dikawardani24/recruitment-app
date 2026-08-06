from app.extraction import Profile
from app.ranking._requirements import Requirements, KNOWN_EDUCATION_LEVELS

class ProfileScore:
    def __init__(self, skill_score: float, experience_score: float, edu_score: float, cert_score: float, weights: dict[str, float]):
        self.skill_score = skill_score
        self.experience_score = experience_score
        self.edu_score = edu_score
        self.cert_score = cert_score
        self.overall = self.__overall(weights)

    def __overall(self, weights: dict[str, float]) -> float:
        total_w = sum(weights.values()) or 1.0
        overall = (
            self.skill_score * weights.get("skill", 0.0)
            + self.experience_score * weights.get("experience", 0.0)
            + self.edu_score * weights.get("education", 0.0)
            + self.cert_score * weights.get("certification", 0.0)
        ) / total_w
        return max(0.0, min(1.0, overall))

class ProfileScoreCounter:
    def __init__(self, profile: Profile, requirements: Requirements):
        self.profile = profile
        self.requirement = requirements

    def __score_req_skills(self, total_matched_req: int, total_req: int, total_matched_pref: int, total_pref: int):
        score_req = 0.7 * (total_matched_req / total_req)
        score_pref = 0.3 * (total_matched_pref / total_pref if total_pref > 0 else 0.0)
        return score_req + score_pref
    
    def __score_pref_skills(self, total_matched_pref: int, total_pref: int):
        return 0.5 + 0.5 * (total_matched_pref / total_pref)
        
    def __count_skill_score(self):
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
    
    def __count_experience_score(self):
        min_years = self.requirement.min_years
        years_experience = self.profile.years_experience
        
        if min_years > 0:
            return min(1.0, years_experience / min_years)
                
        return 0.7 if years_experience > 0 else 0.4
    
    def __count_edu_score(self):
        req_edu = self.requirement.req_edu

        if req_edu:
            requirement_level = KNOWN_EDUCATION_LEVELS.get(req_edu, 0)
            return min(
                1.0, KNOWN_EDUCATION_LEVELS.get(self.profile.education or "", 0) / max(1, requirement_level)
            )
        return 0.8 if self.profile.education else 0.5
    
    def __count_cert_score(self):
        if not self.requirement.req_certs:
            return 0.7 if self.profile.certifications else 0.5
        return len(self.requirement.matched_certs(self.profile)) / len(self.requirement.req_certs)
    
    def count(self, weights: dict[str, float]):
        skill_score= self.__count_skill_score()
        experience_score= self.__count_experience_score()
        edu_score= self.__count_edu_score()
        cert_score= self.__count_cert_score()
        
        return ProfileScore(
            skill_score= skill_score,
            experience_score= experience_score,
            edu_score= edu_score,
            cert_score= cert_score,
            weights=weights,
        )
