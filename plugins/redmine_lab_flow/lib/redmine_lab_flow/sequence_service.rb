# frozen_string_literal: true

module RedmineLabFlow
  class SequenceService
    CODON_TABLE = {
      'TTT' => 'F', 'TTC' => 'F', 'TTA' => 'L', 'TTG' => 'L',
      'TCT' => 'S', 'TCC' => 'S', 'TCA' => 'S', 'TCG' => 'S',
      'TAT' => 'Y', 'TAC' => 'Y', 'TAA' => '*', 'TAG' => '*',
      'TGT' => 'C', 'TGC' => 'C', 'TGA' => '*', 'TGG' => 'W',
      'CTT' => 'L', 'CTC' => 'L', 'CTA' => 'L', 'CTG' => 'L',
      'CCT' => 'P', 'CCC' => 'P', 'CCA' => 'P', 'CCG' => 'P',
      'CAT' => 'H', 'CAC' => 'H', 'CAA' => 'Q', 'CAG' => 'Q',
      'CGT' => 'R', 'CGC' => 'R', 'CGA' => 'R', 'CGG' => 'R',
      'ATT' => 'I', 'ATC' => 'I', 'ATA' => 'I', 'ATG' => 'M',
      'ACT' => 'T', 'ACC' => 'T', 'ACA' => 'T', 'ACG' => 'T',
      'AAT' => 'N', 'AAC' => 'N', 'AAA' => 'K', 'AAG' => 'K',
      'AGT' => 'S', 'AGC' => 'S', 'AGA' => 'R', 'AGG' => 'R',
      'GTT' => 'V', 'GTC' => 'V', 'GTA' => 'V', 'GTG' => 'V',
      'GCT' => 'A', 'GCC' => 'A', 'GCA' => 'A', 'GCG' => 'A',
      'GAT' => 'D', 'GAC' => 'D', 'GAA' => 'E', 'GAG' => 'E',
      'GGT' => 'G', 'GGC' => 'G', 'GGA' => 'G', 'GGG' => 'G'
    }.freeze

    COMMON_ENZYMES = {
      'EcoRI' => 'GAATTC',
      'BamHI' => 'GGATCC',
      'HindIII' => 'AAGCTT',
      'XbaI' => 'TCTAGA',
      'SalI' => 'GTCGAC',
      'PstI' => 'CTGCAG',
      'SmaI' => 'CCCGGG',
      'KpnI' => 'GGTACC',
      'SacI' => 'GAGCTC',
      'XhoI' => 'CTCGAG',
      'NdeI' => 'CATATG',
      'NcoI' => 'CCATGG',
      'NotI' => 'GCGGCCGC',
      'SpeI' => 'ACTAGT',
      'AvrII' => 'CCTAGG'
    }.freeze

    class << self
      def parse_fasta(content)
        sequences = []
        current_name = nil
        current_seq = []

        content.each_line do |line|
          line = line.strip
          if line.start_with?('>')
            if current_name
              sequences << { name: current_name, sequence: current_seq.join }
            end
            current_name = line[1..]
            current_seq = []
          elsif line.present?
            current_seq << line
          end
        end

        if current_name
          sequences << { name: current_name, sequence: current_seq.join }
        end

        sequences
      end

      def parse_genbank(content)
        result = {
          name: nil,
          sequence: nil,
          circular: false,
          annotations: []
        }

        # Parse LOCUS line
        if content =~ /LOCUS\s+(\S+)\s+\d+\s+bp\s+(\S+)?/
          result[:name] = $1
          result[:circular] = content.include?('circular')
        end

        # Parse DEFINITION
        if content =~ /DEFINITION\s+(.+?)(?=ACCESSION|\z)/m
          result[:definition] = $1.strip.gsub(/\s+/, ' ')
        end

        # Parse FEATURES
        content.scan(/^\s{5}(\w+)\s+(complement\()?(\d+)\.\.(\d+)\)?.*?(?=^\s{5}\w|\z)/m) do |type, complement, start_pos, end_pos|
          annotation = {
            type: type,
            start: start_pos.to_i - 1,
            end: end_pos.to_i - 1,
            strand: complement ? -1 : 1
          }

          # Extract label if present
          if $&.to_s =~ /\/label="?([^"\n]+)"?/
            annotation[:name] = $1
          end

          result[:annotations] << annotation
        end

        # Parse ORIGIN (sequence)
        if content =~ /ORIGIN\s+(.*?)\/\//m
          result[:sequence] = $1.gsub(/[\s\d]/, '').upcase
        end

        result
      end

      def to_genbank(sequence)
        output = []

        # LOCUS line
        circular_text = sequence.circular? ? 'circular' : 'linear'
        type_text = case sequence.sequence_type
                    when 'dna', 'plasmid' then 'DNA'
                    when 'rna' then 'RNA'
                    when 'protein' then 'PRT'
                    else 'DNA'
                    end
        output << "LOCUS       #{sequence.name.ljust(16)} #{sequence.length} bp    #{type_text}     #{circular_text} #{Date.current.strftime('%d-%^b-%Y')}"

        # DEFINITION
        output << "DEFINITION  #{sequence.name}"

        # FEATURES header
        output << "FEATURES             Location/Qualifiers"
        output << "     source          1..#{sequence.length}"
        output << "                     /organism=\"#{sequence.issue.project.name}\""

        # Add annotations
        sequence.annotations.each do |ann|
          location = ann.strand == -1 ? "complement(#{ann.start_position + 1}..#{ann.end_position + 1})" : "#{ann.start_position + 1}..#{ann.end_position + 1}"
          output << "     #{ann.annotation_type.ljust(15)} #{location}"
          output << "                     /label=\"#{ann.name}\""
          output << "                     /note=\"#{ann.notes}\"" if ann.notes.present?
        end

        # ORIGIN
        output << "ORIGIN"
        seq = sequence.clean_sequence.downcase
        seq.chars.each_slice(60).with_index do |chunk, idx|
          line_num = (idx * 60 + 1).to_s.rjust(9)
          formatted_chunk = chunk.each_slice(10).map(&:join).join(' ')
          output << "#{line_num} #{formatted_chunk}"
        end
        output << "//"

        output.join("\n")
      end

      def find_restriction_sites(sequence, enzymes = nil)
        enzymes ||= COMMON_ENZYMES.keys
        seq = sequence.clean_sequence.upcase
        sites = []

        enzymes.each do |enzyme|
          pattern = COMMON_ENZYMES[enzyme]
          next unless pattern

          # Find all occurrences
          seq.scan(/(?=#{pattern})/i) do
            position = $~.begin(0)
            sites << {
              enzyme: enzyme,
              pattern: pattern,
              position: position,
              position_end: position + pattern.length - 1
            }
          end

          # For circular sequences, check wrap-around
          if sequence.circular?
            wrap_seq = seq[-pattern.length + 1..] + seq[0..pattern.length - 2]
            if wrap_seq =~ /#{pattern}/i
              sites << {
                enzyme: enzyme,
                pattern: pattern,
                position: seq.length - pattern.length + $~.begin(0) + 1,
                position_end: $~.begin(0) + pattern.length - 1,
                wraps_origin: true
              }
            end
          end
        end

        sites.sort_by { |s| s[:position] }
      end

      def translate(sequence, frame: 1)
        seq = sequence.clean_sequence.upcase
        seq = seq.gsub('U', 'T')

        # Adjust for reading frame
        seq = seq[(frame - 1)..]

        codons = seq.scan(/.{3}/)
        codons.map { |codon| CODON_TABLE[codon] || 'X' }.join
      end

      def reverse_complement(seq)
        complement_map = { 'A' => 'T', 'T' => 'A', 'G' => 'C', 'C' => 'G',
                          'a' => 't', 't' => 'a', 'g' => 'c', 'c' => 'g' }
        seq.chars.reverse.map { |c| complement_map[c] || c }.join
      end

      def gc_content(seq)
        return 0 if seq.blank?
        seq = seq.upcase
        gc_count = seq.count('GC')
        (gc_count.to_f / seq.length * 100).round(2)
      end
    end
  end
end
