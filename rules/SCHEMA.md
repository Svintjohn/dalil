# Rules registry

One YAML file per country in `rules/countries/`, named with the ISO 3166-1 alpha-2 code (`AE.yaml`).

Golden rule: **nothing from memory.** Every fact must come from an official government page that was
opened and read. If a page could not be opened or a rule could not be found, leave it out.

```yaml
country: AE                         # ISO code, same as the file name
name: United Arab Emirates
last_verified: 2026-10-10           # the day the pages were read
portal: {name: UAE Government Portal, url: https://u.ae/en}
official_domains: [u.ae, mohre.gov.ae]   # every URL in this file must be on one of these
authorities:
  - id: mohre
    name: Ministry of Human Resources and Emiratisation
    url: https://www.mohre.gov.ae/
    covers: [employment]            # topics this office handles
    phone: "600590000"              # only if an official page shows it
    phone_source: https://www.mohre.gov.ae/en/contact-us   # required when phone is set
topics:                             # tenancy | employment | fines | consumer | scams | immigration | privacy
  employment:
    sources:
      - {url: https://u.ae/..., title: Labour rights, publisher: UAE Government Portal, language: en}
    facts:
      - id: passport_retention                  # lower_snake_case, unique in the topic
        statement: Employers may not keep an employee's passport.   # one plain sentence, no article numbers
        source_url: https://u.ae/...            # must be on an official domain
        quote: "exact words copied from the page"   # leave "" if you only have a summary
        confidence: quoted                      # quoted (quote present) | summary
        verified_on: 2026-10-10
notes: ""                           # gaps, caveats (for example "tenancy law differs by emirate")
```

Check a file: `python scripts/validate_rules.py rules/countries/AE.yaml`
Re-open every link and quote: `python scripts/check_sources.py --country AE`
