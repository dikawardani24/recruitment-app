# Backend Architecture Flow

## End-to-End Data Flow

```mermaid
flowchart TD
    subgraph Upload_JD["1. Create Job (POST /api/jobs)"]
        A[User uploads JD\nPDF/DOCX/TXT or pastes text]
        A --> B[parsers.extract_text]
        B --> C[jd.structure_jd\nrule-based parsing]
        C --> D[(SQLite: jobs table)]
    end

    subgraph Upload_CVs["2. Upload CVs (POST /api/jobs/{id}/cvs)"]
        E[User uploads CV files]
        E --> F[parsers.extract_text\nPDF/DOCX/TXT]
        F --> G{Extraction Pipeline\nextraction.extract_profile_text}

        G -->|1. NER enabled?| H[extraction._ner\nlocal BERT model]
        G -->|2. LLM key set?| I[extraction._orchestrator\nOpenAI API]
        G -->|3. Fallback| J[extraction._profile\nregex + dictionaries]

        H --> K[Profile dataclass\ncandidate_name, skills,\nyears, education, certs]
        I --> K
        J --> K

        K --> L[(SQLite: cvs table\nstatus=parsed)]
    end

    subgraph Ranking["3. Rank Candidates (POST /api/jobs/{id}/rank)"]
        M[Trigger ranking]
        M --> N[ranking.score_profile\nrule-based scoring]

        N --> O{LLM enabled?}

        O -->|Yes| P[ranking._llm\nOpenAI API\nper-candidate reasoning]
        P --> Q[Update overall score,\nrecommendation, explanation\nfrom LLM]

        O -->|No| R[ranking.rule_reasoning\ndeterministic text]

        N --> S[Compute sub-scores:\nskill_score, experience_score,\neducation_score, cert_score]

        S --> T[(SQLite: cvs table\nscores, bucket,\nrecommendation)]
        Q --> T
        R --> T
    end

    subgraph Results["4. View Rankings (GET /api/jobs/{id}/rankings)"]
        U[Frontend queries rankings]
        U --> V[Sorted by overall_score DESC]
    end
```

## Extraction Pipeline Detail

```mermaid
flowchart LR
    A[Resume Text] --> B{NER enabled?}

    B -->|Yes| C[BERT NER Model\nyashpwr/resume-ner-bert]
    C --> D{Confidence OK?}
    D -->|Yes| E[Extracted Profile]
    D -->|No| F{LLM key set?}

    B -->|No| F

    F -->|Yes| G[OpenAI API\nparse resume fields]
    G --> H{Valid response?}
    H -->|Yes| E
    H -->|No| I[Deterministic Rules\nregex + skill dictionaries]

    F -->|No| I

    I --> E
```

## Ranking Scoring Detail

```mermaid
flowchart TD
    A[Job Requirements] --> B[For each CV]
    B --> C[skill_score\n70% required match\n+ 30% preferred match]
    B --> D[experience_score\nmin 1.0, candidate_years / required_years]
    B --> E[education_score\nlevel comparison: diploma<bsc<msc<phd]
    B --> F[certification_score\nmatched / required]

    C --> G[overall = weighted sum\nw_skill=0.40\nw_experience=0.30\nw_education=0.15\nw_certification=0.15]

    D --> G
    E --> G
    F --> G

    G --> H{overall score}
    H -->|>= 0.85| I[strong_match]
    H -->|>= 0.70| J[good_match]
    H -->|>= 0.50| K[possible_match]
    H -->|< 0.50| L[weak_match]
```

## Module Dependencies

```mermaid
flowchart TD
    main[main.py\nFastAPI app + lifespan]
    config[config.py\nSettings singleton]
    db[db.py\nSQLite schema + async helpers]

    parsers[parsers/\nFile parsing]
    skills[skills/\nSkill dictionaries]
    jd[jd/\nJD structuring]
    extraction[extraction/\nCV profile extraction]
    ranking[ranking/\nScoring + reasoning]
    router[routers/jobs.py\nAll HTTP endpoints]

    main --> config
    main --> db
    main --> router

    router --> config
    router --> db
    router --> parsers
    router --> extraction
    router --> ranking
    router --> jd

    jd --> skills
    extraction --> config
    extraction --> jd
    extraction --> skills
    ranking --> config
    ranking --> extraction
```

## API Endpoints

```mermaid
flowchart LR
    subgraph API["/api"]
        POST_JOB["POST /jobs\nCreate job from text + JD file"]
        GET_JOBS["GET /jobs\nList all jobs"]
        GET_JOB["GET /jobs/{id}\nJob detail + requirements"]
        POST_CVS["POST /jobs/{id}/cvs\nUpload CV files"]
        GET_CVS["GET /jobs/{id}/cvs\nCV processing status"]
        POST_RANK["POST /jobs/{id}/rank\nTrigger AI ranking"]
        GET_RANK["GET /jobs/{id}/rankings\nRanked candidates"]
    end

    HEALTH["GET /health\nHealth check"]
```

## Storage

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `jobs` | Job vacancies | id, title, description, requirements (JSON), status |
| `cvs` | Candidate CVs + scores | id, job_id (FK), file_name, storage_path, status, skills (JSON), overall_score, bucket, recommendation |
