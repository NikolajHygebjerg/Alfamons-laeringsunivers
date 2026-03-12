# Alfamon-kort og tilhørende billeder

Komplet liste over alle kort-SVG'er i assets-mappen (124 filer) og deres mapping til avatar-navne.

## Kort-filer pr. avatar (assets/*kort*.svg)

| Avatar | Stage 1 | Stage 2 | Stage 3 | Stage 4 | Ekstra |
|--------|---------|---------|---------|---------|--------|
| Aarmok | Aarmokkort1.svg | Aarmokkort2.svg | Aarmokkort3.svg | Aarmokkort4.svg | Aarmokkort12, Aarmokkort34 |
| Aelgor | Aelgorkort1.svg | Aelgorkort2.svg | aelgorkort3.svg | aelgorkort4.svg | Aelgor2kort1.svg |
| Atiach | Atiachkort1.svg | Atiachkort2.svg | Atiachkort3.svg | Atiachkort4.svg | |
| Bezzle | Bezzlekort1.svg | Bezzlekort2.svg | Bezzlekort3.svg | Bezzlekort4.svg | |
| Cekimos | Cekimoskort1.svg | Cekimoskort2.svg | Cekimoskort3.svg | Cekimoskort4.svg | |
| Dedoo | Dedookort1.svg | Dedookort2.svg | Dedookort3.svg | Dedookort4.svg | |
| Ellaboo | Ellabookort1.svg | Ellabookort2.svg | Ellabookort3.svg | Ellabookort4.svg | |
| Flizard | Flizardkort1.svg | Flizardkort2.svg | Flizardkort3.svg | Flizardkort4.svg | |
| Gemibull | Gemibullkort1.svg | Gemibullkort2.svg | Gemibullkort3.svg | Gemibullkort4.svg | |
| Haaghai | haaghaikort1.svg | haaghaikort2.svg | haaghaikort3.svg | haaghaikort4.svg | |
| Iffle | Ifflekort1.svg | Ifflekort2.svg | Ifflekort3.svg | Ifflekort4.svg | |
| Jaadrik | Jaadrikkort1.svg | Jaadrikkort2.svg | Jaadrikkort3.svg | Jaadrikkort4.svg | |
| Kåvax | Kåvaxkort1.svg | Kåvaxkort2.svg | Kåvaxkort3.svg | Kåvaxkort4.svg | Kåvaxkort23.svg |
| Lmi | lmikort1.svg | lmikort2.svg | lmikort3.svg | lmikort4.svg | |
| Maxtor | Maxtorkort1.svg | Maxtorkort2.svg | Maxtorkort3.svg | Maxtorkort4.svg | |
| Nimbroo | Nimbrookort1.svg | Nimbrookort2¨.svg | Nimbrookort3.svg | Nimbrookort4.svg | Nimbrookort23.svg |
| Oegleon | Oegleonkort1.svg | Oegleonkort2.svg | Oegleonkort3.svg | Oegleonkort4.svg | |
| Oodlob | oodlobkort1.svg | oodlobkort2.svg | oodlobkort3.svg | oodlobkort4.svg | oodlobkort23, oodlobkort34 |
| Peppapop | Peppapopkort1.svg | Peppapopkort2.svg | Peppapopkort3.svg | Peppapopkort4.svg | |
| Quibbly | Quibblykort1.svg | Quibblykort2.svg | Quibblykort3.svg | Quibblykort4.svg | |
| Rminax | Rminaxkort1.svg | Rminaxkort2.svg | Rminaxkort3.svg | Rminaxkort4.svg | |
| Snake | snakekort1.svg | snakekort2.svg | snakekort3.svg | snakekort4.svg | |
| Tegorm | Tegormkort1.svg | Tegormkort2.svg | Tegormkort3.svg | Tegormkort4.svg | |
| Ummiroo | Ummirookort1.svg | Ummirookort2.svg | Ummirookort3.svg | Ummirookort4.svg | |
| Vindloo | Vindlookort1.svg | Vindlookort2.svg | Vindlookort3.svg | Vindlookort4.svg | |
| Wigloo | wiglookort1.svg | wiglookort2.svg | wiglookort3.svg | wiglookort4.svg | |
| X-bug | X-bugkort1.svg | X-bugkort2.svg | X-bugkort3.svg | X-bugkort4.svg | |
| Yglifax | Yglifaxkort1.svg | Yglifaxkort2.svg | Yglifaxkort3.svg | Yglifaxkort4.svg | Yglifaxkort34.svg |
| Zetbra | Zetbrakort1.svg | Zetbrakort2.svg | Zetbrakort3.svg | Zetbrakort4.svg | |

## Database-navn → Asset-mapping

Se `lib/utils/card_assets.dart` for fuld mapping. Eksempler:
- Iffle, Irile → Ifflekort
- Atiach, Abbas → Atiachkort
- Aelgor → Aelgorkort
- Bezzle, Bazzle, Bazzie, Apego, Adonis → Bezzlekort
- Kåvax, Kavax → Kåvaxkort
- Snake, S-nake, S-nalo, S-males → snakekort
- Wigloo, Wiglook → wiglookort
- osv.

## Rettelser lavet

1. **Solid baggrund** – Kortet har nu brun baggrund (#4A3728) bag billedet, så transparente SVG'er ikke viser baggrunden igennem.
2. **Stjerner fjernet** – Fallback-ikon for ukendte evner er ændret fra `Icons.star` til `Icons.help_outline`.
3. **Nimbrookort2** – Override til `Nimbrookort2¨.svg` (filen har typo).
4. **Aelgor stage 3–4** – Override til lowercase `aelgorkort3.svg`, `aelgorkort4.svg`.
