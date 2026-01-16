# frozen_string_literal: true

module RedmineLabFlow
  class SeedExamples
    PROCEDURE_TEMPLATES = [
      {
        name: 'Standard Operating Procedure (SOP)',
        description: 'General template for standard operating procedures',
        content: <<~MARKDOWN
          # Standard Operating Procedure

          ## 1. Purpose
          [Describe the purpose of this procedure]

          ## 2. Scope
          [Define the scope and applicability]

          ## 3. Responsibilities
          | Role | Responsibility |
          |------|----------------|
          | Analyst | Execute procedure |
          | Supervisor | Review and approve |
          | QA | Verify compliance |

          ## 4. Materials and Equipment
          - [ ] Equipment 1
          - [ ] Equipment 2
          - [ ] Reagent A
          - [ ] Reagent B

          ## 5. Procedure

          ### 5.1 Preparation
          1. Step one
          2. Step two
          3. Step three

          ### 5.2 Execution
          1. Step one
          2. Step two
          3. Step three

          ### 5.3 Post-procedure
          1. Clean equipment
          2. Document results
          3. Dispose of waste properly

          ## 6. Safety Considerations
          > **Warning:** [List any safety hazards]

          - PPE required: [List PPE]
          - Emergency procedures: [Reference emergency protocol]

          ## 7. Quality Control
          - Acceptance criteria: [Define criteria]
          - Calibration requirements: [List requirements]

          ## 8. References
          - [Reference 1]
          - [Reference 2]

          ## 9. Revision History
          | Version | Date | Author | Changes |
          |---------|------|--------|---------|
          | 1.0 | YYYY-MM-DD | [Name] | Initial release |
        MARKDOWN
      },
      {
        name: 'Sample Preparation Protocol',
        description: 'Template for sample preparation procedures',
        content: <<~MARKDOWN
          # Sample Preparation Protocol

          ## Document Control
          - **Protocol ID:** SPP-[NUMBER]
          - **Version:** 1.0
          - **Effective Date:** [DATE]
          - **Review Date:** [DATE + 1 year]

          ## 1. Objective
          To establish a standardized method for preparing samples prior to analysis.

          ## 2. Required Materials

          ### 2.1 Equipment
          | Equipment | Specification | Calibration Due |
          |-----------|---------------|-----------------|
          | Analytical Balance | 0.0001g precision | [DATE] |
          | Vortex Mixer | Variable speed | N/A |
          | Centrifuge | 15,000 RPM max | [DATE] |
          | Pipettes | 10-1000 µL | [DATE] |

          ### 2.2 Reagents
          | Reagent | Grade | Storage | Expiry Check |
          |---------|-------|---------|--------------|
          | Solvent A | HPLC Grade | Room temp | [ ] |
          | Buffer B | ACS Grade | 2-8°C | [ ] |
          | Standard C | Reference | -20°C | [ ] |

          ## 3. Sample Receipt and Logging

          ```
          Sample ID: ________________
          Receipt Date: ________________
          Storage Condition: ________________
          Visual Inspection: [ ] Pass  [ ] Fail
          ```

          ## 4. Preparation Steps

          ### Step 1: Sample Thawing (if frozen)
          - Remove from -80°C storage
          - Thaw at room temperature for 30 minutes
          - **Critical:** Do not use heat to accelerate thawing

          ### Step 2: Weighing
          1. Tare the container
          2. Transfer approximately **100 mg** of sample
          3. Record exact weight: _______ mg

          ### Step 3: Extraction
          1. Add **1.0 mL** of Solvent A
          2. Vortex for **30 seconds**
          3. Sonicate for **10 minutes**
          4. Centrifuge at **10,000 RPM** for **5 minutes**

          ### Step 4: Filtration
          1. Transfer supernatant to clean vial
          2. Filter through 0.22 µm membrane
          3. Collect filtrate in labeled vial

          ## 5. Quality Control Checkpoints

          - [ ] All reagents within expiry date
          - [ ] Equipment calibration current
          - [ ] Sample integrity verified
          - [ ] Procedure followed without deviation

          ## 6. Troubleshooting

          | Issue | Possible Cause | Corrective Action |
          |-------|----------------|-------------------|
          | Incomplete dissolution | Insufficient mixing | Extend vortex time |
          | Cloudy extract | Particulates | Re-filter sample |
          | Low recovery | Sample degradation | Check storage conditions |

          ## 7. Data Recording
          Record all observations in the Daily Log with reference to this protocol version.
        MARKDOWN
      },
      {
        name: 'Analytical Method Protocol',
        description: 'Template for quantitative analytical methods',
        content: <<~MARKDOWN
          # Analytical Method Protocol

          ## Method Information
          - **Method Code:** AM-[NUMBER]
          - **Technique:** [HPLC/GC/MS/UV-Vis/etc.]
          - **Analyte(s):** [Target compound(s)]
          - **Matrix:** [Sample type]

          ## 1. Principle
          [Brief description of the analytical principle]

          ## 2. Instrument Parameters

          ### 2.1 Hardware Configuration
          ```
          Instrument: ________________
          Serial Number: ________________
          Last Maintenance: ________________
          ```

          ### 2.2 Method Settings
          | Parameter | Value | Units |
          |-----------|-------|-------|
          | Column/Detector | [Spec] | - |
          | Temperature | [Value] | °C |
          | Flow Rate | [Value] | mL/min |
          | Injection Volume | [Value] | µL |
          | Run Time | [Value] | min |
          | Wavelength | [Value] | nm |

          ## 3. Calibration

          ### 3.1 Standard Preparation
          | Level | Concentration | Preparation |
          |-------|---------------|-------------|
          | STD-1 | [Low] | [Instructions] |
          | STD-2 | [Mid-Low] | [Instructions] |
          | STD-3 | [Mid] | [Instructions] |
          | STD-4 | [Mid-High] | [Instructions] |
          | STD-5 | [High] | [Instructions] |

          ### 3.2 Calibration Acceptance Criteria
          - Correlation coefficient (r²) ≥ 0.995
          - Back-calculated accuracy: 85-115%
          - Response factor RSD ≤ 15%

          ## 4. Sample Analysis Sequence

          ```
          1. Blank
          2. STD-1 through STD-5
          3. QC Low
          4. Samples (max 10)
          5. QC Mid
          6. Samples (max 10)
          7. QC High
          8. Blank
          9. Bracket Standard
          ```

          ## 5. Calculations

          ### Concentration Formula
          ```
          Concentration (units) = (Peak Area - Intercept) / Slope × Dilution Factor
          ```

          ### Recovery Calculation
          ```
          % Recovery = (Measured / Nominal) × 100
          ```

          ## 6. System Suitability

          | Parameter | Specification | Result | Pass/Fail |
          |-----------|---------------|--------|-----------|
          | Resolution | ≥ 2.0 | _____ | [ ] |
          | Tailing Factor | 0.8-1.5 | _____ | [ ] |
          | Plate Count | ≥ 2000 | _____ | [ ] |
          | Precision (%RSD) | ≤ 2.0 | _____ | [ ] |

          ## 7. Reporting

          Results must be reported with:
          - Method reference and version
          - Analyst identification
          - Analysis date and time
          - Instrument identification
          - Calibration data summary
          - QC results
        MARKDOWN
      },
      {
        name: 'Equipment Calibration Log',
        description: 'Template for equipment calibration records',
        content: <<~MARKDOWN
          # Equipment Calibration Record

          ## Equipment Information
          | Field | Value |
          |-------|-------|
          | Equipment Name | [Name] |
          | Model | [Model] |
          | Serial Number | [S/N] |
          | Location | [Lab/Room] |
          | Asset Tag | [Tag] |

          ## Calibration Details

          ### Calibration Date
          - **Date Performed:** [DATE]
          - **Next Due:** [DATE]
          - **Performed By:** [Name]

          ### Reference Standards Used
          | Standard | Certificate # | Expiry | Traceable To |
          |----------|--------------|--------|--------------|
          | [Std 1] | [Cert #] | [Date] | [NIST/etc.] |
          | [Std 2] | [Cert #] | [Date] | [NIST/etc.] |

          ## Calibration Results

          ### Pre-Calibration Check
          | Test Point | Nominal | Measured | Tolerance | Pass/Fail |
          |------------|---------|----------|-----------|-----------|
          | Point 1 | [Val] | [Val] | ±[Tol] | [ ] |
          | Point 2 | [Val] | [Val] | ±[Tol] | [ ] |
          | Point 3 | [Val] | [Val] | ±[Tol] | [ ] |

          ### Adjustments Made
          - [ ] No adjustment required
          - [ ] Adjustment performed: [Details]

          ### Post-Calibration Verification
          | Test Point | Nominal | Measured | Tolerance | Pass/Fail |
          |------------|---------|----------|-----------|-----------|
          | Point 1 | [Val] | [Val] | ±[Tol] | [ ] |
          | Point 2 | [Val] | [Val] | ±[Tol] | [ ] |
          | Point 3 | [Val] | [Val] | ±[Tol] | [ ] |

          ## Calibration Status

          - [ ] **PASSED** - Equipment is within specifications
          - [ ] **FAILED** - Equipment requires service
          - [ ] **LIMITED USE** - Equipment restricted to [conditions]

          ## Signatures

          | Role | Name | Signature | Date |
          |------|------|-----------|------|
          | Calibrator | | | |
          | Reviewer | | | |

          ## Attachments
          - [ ] Calibration certificate
          - [ ] Raw data printout
          - [ ] Before/After comparison
        MARKDOWN
      },
      {
        name: 'Daily Lab Notebook Entry',
        description: 'Template for daily laboratory notebook entries',
        content: <<~MARKDOWN
          # Daily Lab Notebook Entry

          ## Entry Information
          - **Date:** [DATE]
          - **Analyst:** [NAME]
          - **Project:** [PROJECT NAME/CODE]
          - **Lab Location:** [ROOM/BENCH]

          ## Objectives
          [What do you plan to accomplish today?]

          1. Objective 1
          2. Objective 2
          3. Objective 3

          ## Environmental Conditions
          | Parameter | Value | Acceptable Range |
          |-----------|-------|------------------|
          | Temperature | ___°C | 20-25°C |
          | Humidity | ___% RH | 30-60% |
          | Pressure | ___ mbar | [Range] |

          ## Samples Processed

          | Sample ID | Type | Processing | Status |
          |-----------|------|------------|--------|
          | | | | |
          | | | | |
          | | | | |

          ## Experiments Performed

          ### Experiment 1: [Title]

          **Protocol Reference:** [Link to SOP]

          **Procedure Notes:**
          [Document any deviations from protocol]

          **Observations:**
          [Real-time observations during the experiment]

          **Results:**
          [Preliminary results or data]

          ### Experiment 2: [Title]

          **Protocol Reference:** [Link to SOP]

          **Procedure Notes:**
          [Document any deviations from protocol]

          **Observations:**
          [Real-time observations during the experiment]

          **Results:**
          [Preliminary results or data]

          ## Issues Encountered

          | Time | Issue | Resolution | Follow-up Required |
          |------|-------|------------|-------------------|
          | | | | [ ] Yes  [ ] No |

          ## Conclusions
          [Summary of the day's work and findings]

          ## Tomorrow's Plan
          - [ ] Task 1
          - [ ] Task 2
          - [ ] Task 3

          ## Reagent/Supply Notes
          - [ ] [Item] running low - reorder needed
          - [ ] [Item] expired - dispose and replace

          ---
          **Entry completed at:** [TIME]
          **Review Status:** [ ] Pending  [ ] Reviewed by: ________
        MARKDOWN
      },
      {
        name: 'Investigation Report',
        description: 'Template for laboratory investigation reports',
        content: <<~MARKDOWN
          # Laboratory Investigation Report

          ## Report Information
          - **Investigation ID:** INV-[YEAR]-[NUMBER]
          - **Report Date:** [DATE]
          - **Investigator:** [NAME]
          - **Status:** [ ] Open  [ ] Closed

          ## 1. Executive Summary
          [Brief summary of the investigation and outcome]

          ## 2. Background

          ### 2.1 Event Description
          - **Date of Event:** [DATE]
          - **Time of Event:** [TIME]
          - **Location:** [LAB/AREA]
          - **Personnel Involved:** [NAMES]

          ### 2.2 Initial Report
          [Who reported the issue and initial description]

          ## 3. Investigation Scope
          [Define what is included and excluded from this investigation]

          ## 4. Timeline of Events

          | Date/Time | Event | Source |
          |-----------|-------|--------|
          | | | |
          | | | |
          | | | |

          ## 5. Root Cause Analysis

          ### 5.1 Potential Causes Identified
          1. [Cause 1]
          2. [Cause 2]
          3. [Cause 3]

          ### 5.2 Evidence Reviewed
          - [ ] Laboratory notebooks
          - [ ] Instrument logs
          - [ ] Training records
          - [ ] SOPs and protocols
          - [ ] Calibration records
          - [ ] Environmental monitoring data

          ### 5.3 Root Cause Determination
          [Detailed explanation of the determined root cause]

          ## 6. Impact Assessment

          | Area | Impact | Severity |
          |------|--------|----------|
          | Data Integrity | [Description] | [ ] Low [ ] Medium [ ] High |
          | Product Quality | [Description] | [ ] Low [ ] Medium [ ] High |
          | Safety | [Description] | [ ] Low [ ] Medium [ ] High |

          ## 7. Corrective Actions

          | # | Action | Owner | Due Date | Status |
          |---|--------|-------|----------|--------|
          | 1 | [Action] | [Name] | [Date] | [ ] Open |
          | 2 | [Action] | [Name] | [Date] | [ ] Open |
          | 3 | [Action] | [Name] | [Date] | [ ] Open |

          ## 8. Preventive Actions

          | # | Action | Owner | Due Date | Status |
          |---|--------|-------|----------|--------|
          | 1 | [Action] | [Name] | [Date] | [ ] Open |
          | 2 | [Action] | [Name] | [Date] | [ ] Open |

          ## 9. Conclusions
          [Final conclusions and recommendations]

          ## 10. Approvals

          | Role | Name | Signature | Date |
          |------|------|-----------|------|
          | Investigator | | | |
          | QA Review | | | |
          | Management | | | |

          ## Attachments
          - [ ] Supporting documentation
          - [ ] Photographs
          - [ ] Data files
        MARKDOWN
      }
    ].freeze

    class << self
      def seed_templates
        return unless LabFlowProcedureTemplate.table_exists?

        PROCEDURE_TEMPLATES.each_with_index do |template_def, index|
          next if LabFlowProcedureTemplate.exists?(name: template_def[:name])

          LabFlowProcedureTemplate.create!(
            name: template_def[:name],
            description: template_def[:description],
            content: template_def[:content].strip,
            active: true,
            position: index + 1
          )
          Rails.logger.info "[RedmineLabFlow] Created procedure template: #{template_def[:name]}"
        end
      end

      def seed_example_project_with_wiki(project)
        return unless project&.wiki

        # Create example SOP pages in the wiki
        create_wiki_sop(project, 'Sample-Handling-SOP', sample_handling_sop_content)
        create_wiki_sop(project, 'HPLC-Analysis-Method', hplc_method_content)
        create_wiki_sop(project, 'Quality-Control-Protocol', qc_protocol_content)
      end

      private

      def create_wiki_sop(project, title, content)
        wiki = project.wiki
        return if wiki.find_page(title)

        page = WikiPage.new(wiki: wiki, title: title)
        page.content = WikiContent.new(
          text: content,
          author: User.current,
          comments: 'Initial SOP creation'
        )
        page.save!
        Rails.logger.info "[RedmineLabFlow] Created wiki SOP: #{title}"
      rescue StandardError => e
        Rails.logger.warn "[RedmineLabFlow] Could not create wiki page #{title}: #{e.message}"
      end

      def sample_handling_sop_content
        <<~MARKDOWN
          # Sample Handling Standard Operating Procedure

          **Document ID:** SOP-SH-001
          **Version:** 1.0
          **Effective Date:** #{Date.today.strftime('%Y-%m-%d')}

          ## 1. Purpose

          This SOP establishes standardized procedures for the receipt, storage, and handling of laboratory samples to ensure sample integrity and data quality.

          ## 2. Scope

          This procedure applies to all samples received by the laboratory including:
          - Environmental samples
          - Biological specimens
          - Chemical standards
          - Quality control materials

          ## 3. Responsibilities

          | Role | Responsibility |
          |------|----------------|
          | Sample Custodian | Receive, log, and store samples |
          | Analysts | Handle samples per this SOP |
          | Lab Manager | Ensure compliance |

          ## 4. Sample Receipt

          ### 4.1 Verification Checklist
          - [ ] Chain of custody form complete
          - [ ] Sample containers intact
          - [ ] Labels legible and matching documentation
          - [ ] Temperature requirements met during transport
          - [ ] Sufficient sample volume for requested analyses

          ### 4.2 Logging Procedure
          1. Assign unique Sample ID: `[YEAR]-[MONTH]-[SEQ]`
          2. Enter into LIMS system
          3. Photograph sample condition
          4. Store immediately per requirements

          ## 5. Storage Requirements

          | Sample Type | Temperature | Container | Max Hold Time |
          |-------------|-------------|-----------|---------------|
          | Aqueous | 2-8°C | Glass/HDPE | 14 days |
          | Organic | -20°C | Glass amber | 30 days |
          | Biological | -80°C | Cryovial | 1 year |
          | Standards | Per COA | Original | Per expiry |

          ## 6. Handling Precautions

          > **Safety Notice:** Always wear appropriate PPE when handling samples.

          - Gloves: Nitrile, powder-free
          - Eye protection: Safety glasses minimum
          - Lab coat: Required at all times

          ## 7. Sample Disposal

          All samples must be disposed of according to the laboratory waste management protocol.

          ---
          *This document is controlled. Printed copies are for reference only.*
        MARKDOWN
      end

      def hplc_method_content
        <<~MARKDOWN
          # HPLC Analysis Method

          **Method ID:** AM-HPLC-001
          **Version:** 2.1
          **Technique:** Reversed-Phase HPLC with UV Detection

          ## 1. Principle

          This method utilizes reversed-phase high-performance liquid chromatography (RP-HPLC) with UV detection for the quantitative determination of target analytes in sample matrices.

          ## 2. Instrument Configuration

          | Component | Specification |
          |-----------|---------------|
          | HPLC System | Agilent 1260 Infinity II |
          | Column | C18, 4.6 × 150 mm, 5 µm |
          | Detector | DAD at 254 nm |
          | Autosampler | 100-position, cooled |
          | Column Oven | 40°C |

          ## 3. Mobile Phase

          ### 3.1 Mobile Phase A
          - 0.1% Formic acid in water (v/v)
          - HPLC grade water
          - Filter through 0.22 µm membrane

          ### 3.2 Mobile Phase B
          - Acetonitrile, HPLC grade
          - Use as received

          ### 3.3 Gradient Program

          | Time (min) | %A | %B | Flow (mL/min) |
          |------------|----|----|---------------|
          | 0 | 95 | 5 | 1.0 |
          | 5 | 95 | 5 | 1.0 |
          | 20 | 5 | 95 | 1.0 |
          | 25 | 5 | 95 | 1.0 |
          | 26 | 95 | 5 | 1.0 |
          | 30 | 95 | 5 | 1.0 |

          ## 4. Calibration Standards

          Prepare calibration standards from certified reference material:

          | Level | Concentration (µg/mL) |
          |-------|----------------------|
          | CAL-1 | 0.1 |
          | CAL-2 | 0.5 |
          | CAL-3 | 1.0 |
          | CAL-4 | 5.0 |
          | CAL-5 | 10.0 |

          ## 5. System Suitability Criteria

          | Parameter | Acceptance Criteria |
          |-----------|---------------------|
          | Resolution (Rs) | ≥ 2.0 |
          | Tailing Factor (T) | 0.8 - 1.5 |
          | Theoretical Plates (N) | ≥ 5000 |
          | Injection Precision (%RSD) | ≤ 1.0% |
          | Calibration r² | ≥ 0.999 |

          ## 6. Quality Control

          - QC samples analyzed every 10 samples
          - QC acceptance: 90-110% of nominal
          - Blank analyzed at start and end of sequence

          ---
          *Method validated per ICH Q2(R1) guidelines.*
        MARKDOWN
      end

      def qc_protocol_content
        <<~MARKDOWN
          # Quality Control Protocol

          **Document ID:** QC-PROT-001
          **Version:** 1.0
          **Effective Date:** #{Date.today.strftime('%Y-%m-%d')}

          ## 1. Objective

          To establish quality control procedures that ensure the accuracy, precision, and reliability of laboratory analytical data.

          ## 2. QC Sample Types

          | QC Type | Purpose | Frequency |
          |---------|---------|-----------|
          | Method Blank | Contamination check | Each batch |
          | Lab Fortified Blank (LFB) | Accuracy | Each batch |
          | Lab Fortified Matrix (LFM) | Matrix effects | 10% of samples |
          | Duplicate | Precision | 10% of samples |
          | Certified Reference Material | Trueness | Weekly |

          ## 3. Acceptance Criteria

          ### 3.1 Method Blank
          - All analytes < Method Detection Limit (MDL)
          - If failed: Investigate source, re-prep batch

          ### 3.2 Lab Fortified Blank (LFB)
          | Parameter | Criteria |
          |-----------|----------|
          | Recovery | 80-120% |
          | Action if failed | Check standards, re-analyze |

          ### 3.3 Duplicate Analysis
          | Parameter | Criteria |
          |-----------|----------|
          | RPD | ≤ 20% (aqueous) |
          | RPD | ≤ 30% (solid) |

          ## 4. Control Charts

          Maintain control charts for:
          - [ ] LFB recovery
          - [ ] CRM results
          - [ ] Duplicate precision

          ### Warning and Control Limits
          - Warning: ±2 standard deviations
          - Control: ±3 standard deviations

          ## 5. Out-of-Control Procedures

          ```
          If QC fails:
          1. Stop analysis
          2. Investigate root cause
          3. Implement corrective action
          4. Re-analyze affected samples
          5. Document in QC log
          ```

          ## 6. Documentation Requirements

          All QC data must be:
          - Recorded in laboratory notebook
          - Entered in LIMS
          - Reviewed by supervisor within 24 hours
          - Archived per data retention policy

          ## 7. QC Review and Trending

          Monthly review of QC data for:
          - Systematic bias
          - Precision trends
          - Method performance

          ---
          *Quality is not an act, it is a habit.*
        MARKDOWN
      end
    end
  end
end
