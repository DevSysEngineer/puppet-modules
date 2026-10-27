# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../../../shared/test_support/guide_links'

# Keep tooling, general rules, documentation rules and operational rules in their assigned files.
class GuideStructureTest < Minitest::Test
  include ProjectToolsTestSupport::GuideLinks

  ROOT = File.join(LintTestSupport::ROOT, '.tools/lint/puppet')
  DOCUMENTS = %w[README.md docs/CODE_RULES.md docs/DOCUMENTATION_RULES.md docs/OPERATIONAL_RULES.md].freeze
  INSTRUCTIONS = ['../../../AGENTS.md', '../../AGENTS.md',
                  *Dir.glob('**/AGENTS.md', base: File.join(ROOT, '../..')).map { |path| "../../#{path}" }].freeze
  RULE_GROUPS = {
    'docs/CODE_RULES.md' => ['Algemene ontwerpregels', 'Basisopmaak', 'Inspringing', "Komma's", 'Lange regels',
                             'Parameters en resources'],
    'docs/DOCUMENTATION_RULES.md' => ['Algemene documentatienormen', 'Redactionele review', 'README-richtlijnen',
                                      'Afspraken onderhouden', 'Commentaar en documentatie'],
    'docs/OPERATIONAL_RULES.md' => ['Bestanden en beveiliging', 'Gedeelde services en systemd', 'Shellscripts',
                                    'Monitoringchecks']
  }.freeze
  RULE_OWNERS = {
    'docs/CODE_RULES.md' => ['Gelijk gedrag in één implementatie onderhouden',
                             'Verantwoordelijkheden en interfaces afbakenen',
                             'Inhoud direct na een openingsaccolade beginnen',
                             'Herhaalde resourceorkestratie in defined types delen',
                             'Prerequisites van ordering onderscheiden',
                             'Instellingen bij hun eigenaar houden'],
    'docs/DOCUMENTATION_RULES.md' => ['Strings-parametercontract', 'Codecommentaar in Engelse zinnen schrijven'],
    'docs/OPERATIONAL_RULES.md' => ['Door Puppet beheerde inhoud markeren',
                                    'Beheerhelpers op de gedeelde locatie installeren',
                                    'Interpreter en shellcompatibiliteit', 'Shellscripts in uitvoervolgorde opbouwen',
                                    'Externe commando’s rechtstreeks vinden', 'Shellcode opmaken en benoemen',
                                    'Shellargumenten en runtime-instellingen verwerken',
                                    'Shellhelpers op een herkenbare taak afbakenen',
                                    'Puppet-waarden rechtstreeks in shelltemplates invoegen',
                                    'Shellbuffers en tijdelijke bestanden kiezen',
                                    'Tekstbuffers en substitutiemetadata opbouwen',
                                    'Checkexecutables onafhankelijk van targets delen',
                                    'Monitoring onafhankelijk van de waargenomen taak houden',
                                    'Actuele hosttoestand uit kernelgegevens bepalen',
                                    'Vastgestelde afwijkingen en onvolledige inspecties onderscheiden',
                                    'Firewallconfiguratie bij de deployment houden']
  }.freeze

  def test_all_rule_documents_are_linked_from_the_readme
    readme = prose(File.read(File.join(ROOT, 'README.md')))
    RULE_GROUPS.each_key do |name|
      assert_match(/\]\(#{Regexp.escape(name)}(?:#[^)]*)?\)/, readme, "README must link to #{name}")
    end
  end

  def test_all_assigned_documents_exist_and_have_content
    DOCUMENTS.each do |name|
      path = File.join(ROOT, name)
      assert_path_exists path
      refute_empty File.read(path).strip, name
    end
  end

  def test_rule_groups_have_their_assigned_owner_without_a_second_registry
    RULE_GROUPS.each do |name, groups|
      text = prose(File.read(File.join(ROOT, name)))
      assert_equal ['Inhoudsopgave', *groups], text.scan(/^## (.+)$/).flatten, name
      refute_includes text, '<!-- BEGIN PROJECT CHECK REGISTRY -->', name
      refute_match(/^\| Check \| Actief in repositoryprofiel \|/, text, name)
    end
  end

  def test_all_documents_link_every_heading_in_order_without_duplicate_anchors
    DOCUMENTS.each do |name|
      text = File.read(File.join(ROOT, name))
      contents = text[/^## Inhoudsopgave\n(.*?)(?=^## )/m, 1]
      assert_equal expected_contents(text), contents.lines.grep(/^ *- /).map(&:chomp), name
      assert_equal anchors(text).uniq, anchors(text), "Duplicate anchors in #{name}"
    end
  end

  def test_implementation_topics_have_one_owner_across_all_documentation_layers
    headings = [*DOCUMENTS, *INSTRUCTIONS, '../../../CONTRIBUTING.md', '../../../TESTS.md'].to_h do |name|
      [name, prose(File.read(File.join(ROOT, name))).scan(/^\#{2,6} (.+)$/).flatten]
    end
    RULE_OWNERS.each do |owner, titles|
      titles.each do |title|
        actual = headings.flat_map { |name, entries| [name] * entries.count(title) }
        assert_equal [owner], actual, title
      end
    end
  end

  def test_instruction_layers_do_not_introduce_another_check_registry
    INSTRUCTIONS.each do |name|
      text = prose(File.read(File.join(ROOT, name)))
      refute_includes text, '<!-- BEGIN PROJECT CHECK REGISTRY -->', name
      refute_match(/^\| Check \| Actief in repositoryprofiel \|/, text, name)
    end
  end
end
