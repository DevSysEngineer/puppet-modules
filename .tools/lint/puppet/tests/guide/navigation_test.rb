# frozen_string_literal: true

require_relative '../test_helper'

# Keep workflow and local instructions linked to the authoritative implementation rules.
class GuideNavigationTest < Minitest::Test
  ROOT = File.join(LintTestSupport::ROOT, '.tools/lint/puppet')

  def test_local_instructions_link_the_workflow_and_rule_owners
    instructions = File.read(File.join(ROOT, 'AGENTS.md'))
    %w[../../../AGENTS.md ../../AGENTS.md README.md].each { |path| assert_includes instructions, "(#{path})" }
    %w[instellingen-bij-hun-eigenaar-houden packageafhankelijkheden-bij-externe-commandos].each do |anchor|
      assert_includes instructions, "(docs/CODE_RULES.md##{anchor})"
    end
    %w[actuele-hosttoestand-uit-kernelgegevens-bepalen shellhelpers-op-een-herkenbare-taak-afbakenen
       puppet-waarden-rechtstreeks-in-shelltemplates-invoegen
       vastgestelde-afwijkingen-en-onvolledige-inspecties-onderscheiden].each do |anchor|
      assert_includes instructions, "(docs/OPERATIONAL_RULES.md##{anchor})"
    end
  end

  def test_lint_maintenance_is_owned_by_the_usage_guide_and_required_by_agents
    instructions = File.read(File.join(ROOT, 'AGENTS.md'))
    guide = File.read(File.join(ROOT, 'README.md'))
    %w[checkontwikkeling veilige-autofix-ontwikkelen grenzen-van-de-lintdocumentatie
       documentatiewijzigingen-verifiëren].each do |anchor|
      assert_includes guide, "(##{anchor})"
    end
    assert_includes instructions, '(README.md#documentatiecontract-voor-maintainers)'
    assert_includes instructions, '(README.md#beschikbare-projectchecks)'
  end

  def test_workflow_navigation_links_to_the_owning_operational_rules
    instructions = File.read(File.join(LintTestSupport::ROOT, 'AGENTS.md'))
    assert_includes instructions, '(.tools/lint/puppet/README.md#leeswijzer)'
    assert_includes instructions, '(.tools/lint/puppet/docs/OPERATIONAL_RULES.md)'
    guide = File.read(File.join(ROOT, 'README.md'))
    %w[shellscripts monitoringchecks door-puppet-beheerde-inhoud-markeren
       beheerhelpers-op-de-gedeelde-locatie-installeren shellhelpers-op-een-herkenbare-taak-afbakenen
       actuele-hosttoestand-uit-kernelgegevens-bepalen
       vastgestelde-afwijkingen-en-onvolledige-inspecties-onderscheiden].each do |anchor|
      assert_includes guide, "docs/OPERATIONAL_RULES.md##{anchor})"
    end
  end
end
