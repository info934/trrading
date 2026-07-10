# Lokální tržní data

Tato složka je určena pro stažená a odvozená historická data. Její obsah Git
ignoruje, kromě tohoto souboru a `.gitkeep`.

Doporučení:

- držet pouze nezbytný časový rozsah,
- používat komprimovaný Parquet místo CSV,
- odvozená data regenerovat a po dokončení experimentu mazat,
- velký dataset uložit mimo OneDrive a v konfiguraci uvést jeho cestu,
- nikdy nepřidávat tržní data do Git historie.
