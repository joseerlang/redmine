# frozen_string_literal: true

require 'builder'

module RedmineLabFlow
  class FairExporter
    def initialize(issue, metadata)
      @issue = issue
      @metadata = metadata || LabFlowFairMetadata.new(issue: issue)
    end

    def to_schema_org
      @metadata.to_schema_org.merge(
        'url' => issue_url,
        'isPartOf' => {
          '@type' => 'Project',
          'name' => @issue.project.name,
          'identifier' => @issue.project.identifier
        },
        'author' => {
          '@type' => 'Person',
          'name' => @issue.author.name,
          '@id' => @metadata.orcid_creator.present? ? "https://orcid.org/#{@metadata.orcid_creator}" : nil
        }.compact
      ).compact
    end

    def to_datacite_xml
      xml = Builder::XmlMarkup.new(indent: 2)
      xml.instruct!

      xml.resource(
        'xmlns' => 'http://datacite.org/schema/kernel-4',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
        'xsi:schemaLocation' => 'http://datacite.org/schema/kernel-4 http://schema.datacite.org/meta/kernel-4.4/metadata.xsd'
      ) do
        if @metadata.doi.present?
          xml.identifier(@metadata.doi, identifierType: 'DOI')
        else
          xml.identifier(@issue.id.to_s, identifierType: 'Local')
        end

        xml.creators do
          xml.creator do
            xml.creatorName(@issue.author.name)
            if @metadata.orcid_creator.present?
              xml.nameIdentifier(@metadata.orcid_creator, nameIdentifierScheme: 'ORCID', schemeURI: 'https://orcid.org')
            end
          end
        end

        xml.titles do
          xml.title(@issue.subject)
        end

        xml.publisher(@issue.project.name)
        xml.publicationYear(@issue.created_on.year)
        xml.resourceType(@metadata.schema_org_type || 'Dataset', resourceTypeGeneral: 'Dataset')

        if @metadata.keywords.any?
          xml.subjects do
            @metadata.keywords.each do |keyword|
              xml.subject(keyword)
            end
          end
        end

        if @issue.description.present?
          xml.descriptions do
            xml.description(@issue.description, descriptionType: 'Abstract')
          end
        end

        if @metadata.license.present?
          xml.rightsList do
            license_info = license_details(@metadata.license)
            xml.rights(license_info[:name], rightsURI: license_info[:uri], rightsIdentifier: @metadata.license)
          end
        end

        xml.dates do
          xml.date(@issue.created_on.iso8601, dateType: 'Created')
          xml.date(@issue.updated_on.iso8601, dateType: 'Updated')
          if @metadata.embargo_until.present?
            xml.date(@metadata.embargo_until.iso8601, dateType: 'Available')
          end
        end

        if @metadata.related_identifiers.any?
          xml.relatedIdentifiers do
            @metadata.related_identifiers.each do |ri|
              type = ri.start_with?('10.') ? 'DOI' : 'URL'
              xml.relatedIdentifier(ri, relatedIdentifierType: type, relationType: 'IsPartOf')
            end
          end
        end

        if @metadata.funding_reference.present?
          xml.fundingReferences do
            xml.fundingReference do
              xml.funderName(@metadata.funding_reference)
            end
          end
        end
      end
    end

    def to_ro_crate
      {
        '@context' => 'https://w3id.org/ro/crate/1.1/context',
        '@graph' => [
          {
            '@type' => 'CreativeWork',
            '@id' => 'ro-crate-metadata.json',
            'conformsTo' => { '@id' => 'https://w3id.org/ro/crate/1.1' },
            'about' => { '@id' => './' }
          },
          {
            '@type' => 'Dataset',
            '@id' => './',
            'identifier' => @metadata.doi || @issue.id.to_s,
            'name' => @issue.subject,
            'description' => @issue.description,
            'dateCreated' => @issue.created_on.iso8601,
            'dateModified' => @issue.updated_on.iso8601,
            'license' => license_url(@metadata.license),
            'creator' => {
              '@type' => 'Person',
              'name' => @issue.author.name,
              '@id' => @metadata.orcid_creator.present? ? "https://orcid.org/#{@metadata.orcid_creator}" : nil
            }.compact,
            'keywords' => @metadata.keywords.join(', ')
          }.compact
        ]
      }
    end

    def to_isa_tab
      lines = []

      lines << 'ONTOLOGY SOURCE REFERENCE'
      lines << "Term Source Name\tOBI\tCHEBI\tNCIT"
      lines << "Term Source File\t\t\t"
      lines << "Term Source Version\t\t\t"
      lines << ''

      lines << 'INVESTIGATION'
      lines << "Investigation Identifier\t#{@issue.project.identifier}"
      lines << "Investigation Title\t#{@issue.project.name}"
      lines << "Investigation Description\t#{@issue.project.description}"
      lines << ''

      lines << 'INVESTIGATION CONTACTS'
      lines << "Investigation Person Last Name\t#{@issue.author.lastname}"
      lines << "Investigation Person First Name\t#{@issue.author.firstname}"
      lines << "Investigation Person Email\t#{@issue.author.mail}"
      lines << ''

      lines << 'STUDY'
      lines << "Study Identifier\t#{@issue.id}"
      lines << "Study Title\t#{@issue.subject}"
      lines << "Study Description\t#{@issue.description}"
      lines << "Study File Name\ts_#{@issue.id}.txt"
      lines << ''

      if @issue.custom_field_values.any?
        lines << 'STUDY FACTORS'
        @issue.custom_field_values.each do |cfv|
          lines << "Study Factor Name\t#{cfv.custom_field.name}"
          lines << "Study Factor Type\t"
        end
      end

      lines.join("\n")
    end

    private

    def issue_url
      Rails.application.routes.url_helpers.issue_url(
        @issue,
        host: Setting.host_name,
        protocol: Setting.protocol
      )
    rescue StandardError
      nil
    end

    def license_details(license_code)
      case license_code
      when 'CC0'
        { name: 'CC0 1.0 Universal', uri: 'https://creativecommons.org/publicdomain/zero/1.0/' }
      when 'CC-BY-4.0'
        { name: 'Creative Commons Attribution 4.0 International', uri: 'https://creativecommons.org/licenses/by/4.0/' }
      when 'CC-BY-SA-4.0'
        { name: 'Creative Commons Attribution-ShareAlike 4.0', uri: 'https://creativecommons.org/licenses/by-sa/4.0/' }
      when 'CC-BY-NC-4.0'
        { name: 'Creative Commons Attribution-NonCommercial 4.0', uri: 'https://creativecommons.org/licenses/by-nc/4.0/' }
      when 'MIT'
        { name: 'MIT License', uri: 'https://opensource.org/licenses/MIT' }
      when 'Apache-2.0'
        { name: 'Apache License 2.0', uri: 'https://www.apache.org/licenses/LICENSE-2.0' }
      else
        { name: license_code, uri: nil }
      end
    end

    def license_url(license_code)
      license_details(license_code)[:uri]
    end
  end
end
