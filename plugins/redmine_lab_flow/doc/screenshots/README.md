# Screenshots for LabFlow Documentation

Place your screenshots in this directory with the following naming convention:

## Required Screenshots

| Filename | Description | Suggested Content |
|----------|-------------|-------------------|
| `01_dashboard_overview.png` | Main Lab Flow dashboard | Show metrics, recent issues, quick links |
| `02_sample_registration.png` | Sample creation form | New Sample form with custom fields |
| `03_daily_log_wiki.png` | Daily Log with Wiki link | Daily Log showing linked procedure |
| `04_assay_signature.png` | Electronic signature modal | Password prompt with signature meaning |
| `05_molecule_properties.png` | Molecular properties page | SMILES structure with calculated properties |
| `06_sequence_viewer.png` | DNA sequence display | Colored nucleotides with header info |
| `07_restriction_sites.png` | Restriction site analysis | Table of enzymes and cut positions |
| `08_report_generation.png` | Report template selection | Report generation form |
| `09_fair_metadata.png` | FAIR metadata form | DOI, ORCID, license fields |
| `10_integrations.png` | External systems list | Galaxy/OpenBIS configuration |

## Screenshot Guidelines

1. **Resolution**: 1200px wide minimum
2. **Format**: PNG preferred
3. **Content**: Use realistic but non-sensitive data
4. **Browser**: Hide bookmarks bar, use clean browser window
5. **Theme**: Use default Redmine theme for consistency

## Taking Screenshots

### Linux (GNOME)
```bash
gnome-screenshot -a  # Select area
```

### macOS
```bash
Cmd + Shift + 4  # Select area
```

### Windows
```
Win + Shift + S  # Snipping tool
```

## Image Optimization

Before committing, optimize images:

```bash
# Install optipng
sudo apt install optipng

# Optimize all PNGs
for f in *.png; do optipng -o5 "$f"; done
```
