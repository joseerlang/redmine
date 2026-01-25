# frozen_string_literal: true

module RedmineLabFlow
  class MoleculeService
    class << self
      def canonicalize(smiles)
        return nil if smiles.blank?
        smiles.strip
      end

      def smiles_to_inchi(smiles)
        return nil if smiles.blank?
        # Full conversion requires RDKit or OpenBabel
        nil
      end

      def smiles_to_mol(smiles)
        return nil if smiles.blank?
        nil
      end

      def render_svg(smiles)
        return nil if smiles.blank?
        # Server-side SVG generation would use RDKit Python
        # For now, return nil and let client-side handle it
        nil
      end

      def calculate_properties(smiles)
        return {} if smiles.blank?

        atom_counts = count_atoms(smiles)
        formula = build_formula(atom_counts)
        mw = estimate_molecular_weight(atom_counts)

        # Estimate H-bond donors and acceptors
        hbd = estimate_hbd(smiles)
        hba = estimate_hba(smiles)

        # Estimate LogP using simple atom contribution method
        logp = estimate_logp(smiles, atom_counts)

        # Estimate TPSA (Topological Polar Surface Area)
        tpsa = estimate_tpsa(smiles)

        # Count rotatable bonds
        rotatable = count_rotatable_bonds(smiles)

        {
          formula: formula,
          molecular_weight: mw,
          'LogP' => logp,
          'TPSA' => tpsa,
          'HBD' => hbd,
          'HBA' => hba,
          'numRotatableBonds' => rotatable,
          atom_counts: atom_counts
        }
      end

      def substructure_search(query_smiles, limit: 100)
        return [] if query_smiles.blank?
        LabFlowMoleculeCache.where('smiles LIKE ?', "%#{query_smiles}%").limit(limit)
      end

      def similarity_search(query_smiles, threshold: 0.7, limit: 100)
        return [] if query_smiles.blank?
        cache = LabFlowMoleculeCache.find_by(smiles: query_smiles)
        cache ? [cache] : []
      end

      def valid_smiles?(smiles)
        return false if smiles.blank?
        smiles.match?(/\A[A-Za-z0-9@\[\]\(\)\-\=\#\$\:\.\+\\\/\%]+\z/)
      end

      private

      def estimate_properties(smiles)
        atom_counts = count_atoms(smiles)

        formula = build_formula(atom_counts)
        mw = estimate_molecular_weight(atom_counts)

        {
          formula: formula,
          molecular_weight: mw,
          log_p: nil,
          tpsa: nil,
          hbd: smiles.scan(/[ON]H?\d?/).count,
          hba: smiles.scan(/[ON]/).count
        }
      end

      def count_atoms(smiles)
        counts = Hash.new(0)

        # Remove stereochemistry, ring closures, bonds, and brackets
        clean = smiles.gsub(/[@\[\]\\\/\(\)\-\=\#\:\+\%\d]/, '')

        # Handle aromatic atoms (lowercase) - convert to uppercase
        # c = aromatic carbon, n = aromatic nitrogen, o = aromatic oxygen, s = aromatic sulfur
        aromatic_map = { 'c' => 'C', 'n' => 'N', 'o' => 'O', 's' => 'S' }

        # Count single lowercase aromatic atoms
        clean.scan(/[cnos]/).each do |atom|
          counts[aromatic_map[atom]] += 1
        end

        # Remove lowercase atoms for next step
        clean = clean.gsub(/[cnos]/, '')

        # Count uppercase atoms (two-letter elements like Cl, Br first)
        clean.scan(/[A-Z][a-z]?/).each do |atom|
          counts[atom] += 1
        end

        # Estimate hydrogens based on valence rules
        # This is a simplification - proper hydrogen count requires full molecule parsing
        if counts['C'] > 0
          aromatic_c = smiles.scan(/c/).count
          aliphatic_c = counts['C'] - aromatic_c

          # Count ring closures (digits in SMILES indicate ring connections)
          ring_closures = smiles.scan(/\d/).count / 2 # Each ring closure uses 2 digits

          # For aromatic carbons: typically 1H each (in 6-membered rings)
          # For aliphatic carbons: start with saturation formula CnH(2n+2)
          # then subtract for rings and multiple bonds
          h_from_aliphatic = aliphatic_c > 0 ? (aliphatic_c * 2 + 2) : 0
          h_from_aromatic = aromatic_c  # 1H per aromatic carbon

          counts['H'] = h_from_aliphatic + h_from_aromatic

          # Adjust for ring closures (each ring removes 2H)
          counts['H'] -= ring_closures * 2

          # Adjust for heteroatoms replacing C-H bonds
          counts['H'] -= counts['N'] if counts['N'] > 0
          counts['H'] -= counts['O'] * 2 if counts['O'] > 0  # O takes 2 bonds
          counts['H'] -= counts['S'] * 2 if counts['S'] > 0

          # Adjust for explicit double/triple bonds (outside aromatic rings)
          double_bonds = smiles.count('=')
          triple_bonds = smiles.count('#')
          counts['H'] -= double_bonds * 2
          counts['H'] -= triple_bonds * 4

          # Ensure non-negative
          counts['H'] = [counts['H'], 0].max
        end

        counts
      end

      def build_formula(counts)
        formula = ''
        %w[C H].each do |elem|
          next unless counts[elem] > 0

          formula += elem
          formula += counts[elem].to_s if counts[elem] > 1
        end

        (counts.keys - %w[C H]).sort.each do |elem|
          next unless counts[elem] > 0

          formula += elem
          formula += counts[elem].to_s if counts[elem] > 1
        end

        formula
      end

      def estimate_molecular_weight(counts)
        weights = {
          'H' => 1.008, 'C' => 12.011, 'N' => 14.007, 'O' => 15.999,
          'S' => 32.065, 'P' => 30.974, 'F' => 18.998, 'Cl' => 35.453,
          'Br' => 79.904, 'I' => 126.90
        }

        counts.sum { |atom, count| (weights[atom] || 0) * count }.round(2)
      end

      # Estimate H-bond donors (OH, NH, NH2 groups)
      def estimate_hbd(smiles)
        # Count -OH groups (not in rings or special contexts)
        oh_count = smiles.scan(/O(?![a-z])/).count
        # Count -NH and -NH2 groups
        nh_count = smiles.scan(/N(?![a-z])/).count
        # Subtract N in nitro groups, nitriles, etc.
        nitro = smiles.scan(/\[N\+\]/).count
        nitrile = smiles.scan(/C#N/).count

        [oh_count + nh_count - nitro - nitrile, 0].max
      end

      # Estimate H-bond acceptors (N and O atoms)
      def estimate_hba(smiles)
        # Count O atoms
        o_count = smiles.scan(/O(?![a-z])/).count
        # Count N atoms
        n_count = smiles.scan(/N(?![a-z])/).count
        # Subtract positively charged N
        n_plus = smiles.scan(/\[N\+\]/).count

        o_count + n_count - n_plus
      end

      # Estimate LogP using Wildman-Crippen-like atom contributions
      def estimate_logp(smiles, atom_counts)
        # Simplified atom contribution values
        contributions = {
          'C' => 0.29,   # aliphatic carbon
          'H' => 0.12,   # hydrogen
          'N' => -0.77,  # nitrogen
          'O' => -0.45,  # oxygen
          'S' => 0.88,   # sulfur
          'F' => 0.37,   # fluorine
          'Cl' => 0.71,  # chlorine
          'Br' => 0.86,  # bromine
          'I' => 1.14,   # iodine
          'P' => 0.49    # phosphorus
        }

        logp = 0.0
        atom_counts.each do |atom, count|
          logp += (contributions[atom] || 0) * count
        end

        # Adjust for aromatic rings (benzene-like structures)
        aromatic_rings = smiles.scan(/c1.*c.*c.*c.*c.*c1/i).count
        aromatic_rings += smiles.downcase.scan(/c1ccccc1/).count
        logp += aromatic_rings * 1.5

        # Adjust for double bonds (slightly more lipophilic)
        double_bonds = smiles.count('=')
        logp -= double_bonds * 0.1

        logp.round(2)
      end

      # Estimate TPSA (Topological Polar Surface Area)
      def estimate_tpsa(smiles)
        # Simplified TPSA contributions (Å²)
        # Based on Ertl et al. contributions
        tpsa = 0.0

        # Oxygen contributions
        # -OH: ~20.23 Å²
        oh_count = smiles.scan(/O(?!\=)(?![a-z])/).count - smiles.scan(/\=O/).count
        tpsa += oh_count * 20.23

        # =O (carbonyl): ~17.07 Å²
        carbonyl = smiles.scan(/\=O/).count
        tpsa += carbonyl * 17.07

        # Nitrogen contributions
        # -NH2: ~26.02 Å²
        # -NH-: ~12.03 Å²
        # -N<: ~3.24 Å²
        n_count = smiles.scan(/N(?![a-z])/).count
        # Rough estimate - assume mix
        tpsa += n_count * 12.0

        # Adjust for special groups
        # Sulfonamide, phosphate, etc. have higher TPSA
        sulfonamide = smiles.scan(/S\(=O\)\(=O\)N/).count
        tpsa += sulfonamide * 50.0

        tpsa.round(2)
      end

      # Count rotatable bonds
      def count_rotatable_bonds(smiles)
        # Rotatable bond = single bond between two non-terminal heavy atoms
        # Exclude: bonds in rings, bonds to terminal atoms, amide bonds

        # Simple heuristic: count single bonds between heavy atoms
        # minus ring bonds and terminal bonds
        single_bonds = 0

        # Count single bonds (not double, triple, or aromatic)
        # Look for patterns like C-C, C-N, C-O where - is a single bond
        clean = smiles.gsub(/\[.*?\]/, 'X') # Replace bracketed atoms

        # Count carbons and heteroatoms that could form rotatable bonds
        heavy_atoms = clean.scan(/[CNOS]/).count

        # Estimate: roughly (heavy_atoms - ring_atoms - terminal_atoms - 1)
        # For simple chains: n-1 bonds for n atoms
        # Subtract estimated ring bonds

        ring_indicators = clean.scan(/\d/).uniq.count # Ring closure digits
        estimated_ring_atoms = ring_indicators * 5 # Rough estimate

        # Terminal atoms (halogens, -OH, -NH2 at chain ends)
        terminal = clean.scan(/[FClBrI]/).count

        rotatable = [heavy_atoms - estimated_ring_atoms - terminal - 1, 0].max

        # Cap at reasonable value
        [rotatable, 15].min
      end
    end
  end
end
