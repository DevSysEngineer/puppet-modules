# frozen_string_literal: true

require 'digest'
require 'project_lint/parameter_source'
require 'project_lint/module_resolver'
require 'project_lint/section_layout'
require 'project_lint/token_helpers'

module ProjectLint
  # Native manifest checks.
  module Checks
    # Extract only reviewed calls on ordinary data, without evaluating manifest functions.
    module DuplicateFunctionCalls
      # Function signatures and reviewed implementation identities are private to this check.
      module Registry
        DATA = 'Data'
        SCALAR = 'ScalarData'
        NUMBER = 'Numeric'
        COLLECTION = 'Variant[Array[Data], Hash[String, Data]]'
        TEXT_OR_COLLECTION = 'Variant[String, Array[Data], Hash[String, Data]]'
        CONVERTIBLE = 'Variant[String, Numeric, Boolean]'

        # Each entry declares the result and the complete positional signatures accepted here.
        # Optional forms are explicit; native dispatches outside these signatures stay excluded.
        FUNCTIONS = {
          'String' => ['String', [[DATA], [DATA, 'String[1]']]],
          'Integer' => ['Integer', [[CONVERTIBLE], [CONVERTIBLE, 'Integer'], [CONVERTIBLE, 'Integer', 'Boolean']]],
          'Float' => ['Float', [[CONVERTIBLE], [CONVERTIBLE, 'Boolean']]],
          'Boolean' => ['Boolean', [[CONVERTIBLE]]],
          'Array' => ['Array[Data]', [[COLLECTION], [COLLECTION, 'Boolean'], [DATA, 'Boolean[true]']]],
          'Hash' => ['Hash[String, Data]', [['Hash[String, Data]'], ['Array[ScalarData]'],
                                            ['Array[Tuple[String, Data]]']]],
          'downcase' => ['String', [['String']]],
          'upcase' => ['String', [['String']]],
          'capitalize' => ['String', [['String']]],
          'strip' => ['String', [['String']]],
          'lstrip' => ['String', [['String']]],
          'rstrip' => ['String', [['String']]],
          'chomp' => ['String', [['String']]],
          'chop' => ['String', [['String']]],
          'sprintf' => ['String', [['String', SCALAR]], :format_arguments],
          'join' => ['String', [['Array[Data]'], ['Array[Data]', 'String']]],
          'split' => ['Array[String]', [['String', 'Variant[String, Regexp]']]],
          'regsubst' => ['String', [['String', 'Variant[String, Regexp]', 'String'],
                                    ['String', 'Variant[String, Regexp]', 'String', 'String']]],
          'keys' => ['Array[ScalarData]', [['Hash[String, Data]']]],
          'values' => ['Array[Data]', [['Hash[String, Data]']]],
          'dig' => [DATA, [[COLLECTION, 'Variant[String, Integer]']], :dig_arguments],
          'length' => ['Integer', [[TEXT_OR_COLLECTION]]],
          'size' => ['Integer', [[TEXT_OR_COLLECTION]]],
          'empty' => ['Boolean', [[TEXT_OR_COLLECTION]]],
          'flatten' => ['Array[Data]', [['Array[Data]']]],
          'sort' => ['Array[Data]', [['Array[String]'], ['Array[Numeric]']]],
          'unique' => ['Array[Data]', [['Array[Data]']]],
          'abs' => [NUMBER, [[NUMBER]]],
          'floor' => ['Integer', [[NUMBER]]],
          'ceiling' => ['Integer', [[NUMBER]]],
          'round' => ['Integer', [[NUMBER]]],
          'stdlib::to_json' => ['String', [[DATA]]],
          'stdlib::to_json_pretty' => ['String', [[COLLECTION], [COLLECTION, 'Boolean']]],
          'stdlib::to_yaml' => ['String', [[DATA]]],
          'stdlib::merge' => ['Hash[String, Data]', [['Hash[String, Data]']], :merge_arguments],
          'stdlib::shell_escape' => ['String', [['String']]],
          'stdlib::sha256' => ['String', [[SCALAR]]],
          'stdlib::seeded_rand' => ['Integer', [['Integer[1]', 'String']]],
          'shell_join' => ['String', [['Array[String]']]],
          'shell_split' => ['Array[String]', [['String']]],
          'base64' => ['String', [["Enum['encode', 'decode']", 'String'],
                                  ["Enum['encode', 'decode']", 'String', "Enum['default', 'strict', 'urlsafe']"]]],
          'basename' => ['String', [['String'], %w[String String]]],
          'dirname' => ['String', [['String[1]']]]
        }.freeze

        # Reviewed stdlib 10.1.0 implementations; changed or shadowed sources are excluded.
        STDLIB_SOURCES = {
          'stdlib::to_json' => ['lib/puppet/functions/stdlib/to_json.rb',
                                '20941f30afeaa4008466f7fdbafeee3e95d8bcc548871c2579ebf6af803cbee6'],
          'stdlib::to_json_pretty' => ['lib/puppet/functions/stdlib/to_json_pretty.rb',
                                       'dc416d0ccedea8580428fe3300c438ff5c5f89463731cdad885c9dff767a5410'],
          'stdlib::to_yaml' => ['lib/puppet/functions/stdlib/to_yaml.rb',
                                '69e187801f95159bbde25c7d0a6d54774e863fec1b73c6b24dd9efb0c566b42a'],
          'stdlib::merge' => ['lib/puppet/functions/stdlib/merge.rb',
                              '999002a9876b0893c70623b736a2ec4730bbd1df7219e10a26c79ee6dabd542f'],
          'stdlib::shell_escape' => ['lib/puppet/functions/stdlib/shell_escape.rb',
                                     '55382f27d0562f06492417e5bf040ea1212168dd8282d46d8783cc3c2c7b8ae6'],
          'stdlib::sha256' => ['lib/puppet/functions/stdlib/sha256.rb',
                               'f5a79f68cca6b02936f4bc630fa3b02f2d5294795985e3abacd109543e809682'],
          'stdlib::seeded_rand' => ['lib/puppet/functions/stdlib/seeded_rand.rb',
                                    '778dbf15c1c3dc3b9e4366a3c0e19394e10ae654da1fb15c5813d1f0395c8775'],
          'stdlib::rewrap_sensitive_data' => ['lib/puppet/functions/stdlib/rewrap_sensitive_data.rb',
                                              '9a6917d7cb116eaf27d7559e72be443afe9bbff96229729dcffa3eb3c14ba15c'],
          'shell_join' => ['lib/puppet/parser/functions/shell_join.rb',
                           '3e5b0bdec93b873092be4dc218d5d9d628a44a60922e67dbdf549174bedc8fdd'],
          'shell_split' => ['lib/puppet/parser/functions/shell_split.rb',
                            '1d8fbafcd4e5324f264efb682f886899f5dcf5adacd80fb7f4e4e0edb999021b'],
          'base64' => ['lib/puppet/parser/functions/base64.rb',
                       'd295b995d0e110d46751b57fa32ffce0b5f3edac7ef1e1ad0dd82ef402b9b1fe'],
          'basename' => ['lib/puppet/parser/functions/basename.rb',
                         'fefdff8d8cdbe843383eb13f42555aedcba95aa16b5ab4dcd814cf6852822cb1'],
          'dirname' => ['lib/puppet/parser/functions/dirname.rb',
                        '25b37e8af49f6d595af5c48dc46f33ff5b636090e32365a7d24c54397ec0ab20']
        }.freeze

        # Resolve types from a closed vocabulary. Type aliases and object constructors are never loaded.
        TYPE_NAMES = %w[String Integer Float Numeric Boolean Undef Data ScalarData Array Hash
                        Optional Variant Enum Tuple Struct Pattern].freeze
      end

      # Follow static bindings separately from execution branches.
      module Types
        def type(text)
          @types[text] ||= Puppet::Pops::Types::TypeParser.singleton.parse(text)
        end

        def fits?(expected, actual)
          actual && type(expected).assignable?(actual)
        end

        def declared_type(node)
          return unless node

          parts = [node] + ast.descendants(node)
          return unless parts.all? { |part| type_part?(part) }

          result = type(@source[node.offset, node.length])
          result if fits?(Registry::DATA, result)
        end

        def type_part?(node)
          case node
          when Ast::M::QualifiedReference then Registry::TYPE_NAMES.include?(node.cased_value)
          when Ast::M::QualifiedName then node.value == 'default'
          else
            [Ast::M::AccessExpression, Ast::M::LiteralInteger, Ast::M::LiteralFloat,
             Ast::M::LiteralString, Ast::M::LiteralBoolean, Ast::M::LiteralHash,
             Ast::M::KeyedEntry, Ast::M::UnaryMinusExpression].any? { |kind| node.is_a?(kind) }
          end
        end

        def variable_info(node, seen)
          return unless node.expr.value.match?(/\A[a-z_][a-z0-9_]*\z/)

          binding, value_type = variable_binding(node, seen)
          return unless binding && value_type

          { key: [:variable, binding.object_id, node.expr.value], type: value_type }
        end

        def variable_binding(node, seen)
          parents = @parents.fetch(node)
          scope = ast.scope_of(parents)
          assignments = @values.assignments(node, parents)
          return assigned_binding(node, parents, assignments, seen) unless assignments.empty?

          parameter_binding(scope, node.expr.value)
        end

        def parameter_binding(scope, name)
          parameter = scope.parameters.find { |item| item.name == name } if scope.respond_to?(:parameters)
          return [parameter, declared_type(parameter.type_expr)] if parameter

          [scope, type('String')] if scope.is_a?(Ast::M::ResourceTypeDefinition) && %w[name title].include?(name)
        end

        def assigned_binding(node, parents, assignments, seen)
          return unless assignments.one?

          assignment, ancestors = assignments.first
          return unless assignment.offset < node.offset && enclosing_path?(ancestors, parents)

          value_type = expression(assignment.right_expr, seen)&.fetch(:type) || lookup_type(assignment.right_expr)
          [assignment, value_type]
        end

        def enclosing_path?(ancestors, parents)
          ancestors.all? { |ancestor| parents.any? { |parent| ancestor.equal?(parent) } }
        end

        def lookup_type(node)
          return unless typed_lookup?(node)
          return unless node.arguments.first.is_a?(Ast::M::LiteralString)
          return unless resolved?('lookup')

          declared_type(node.arguments.last)
        end

        def typed_lookup?(node)
          node.is_a?(Ast::M::CallNamedFunctionExpression) && call_name(node) == 'lookup' &&
            !node.lambda && node.arguments.length == 2
        end
      end

      # Build ordered structural keys while proving ordinary input types.
      module Expressions
        def expression(node, seen = [])
          node = @values.unwrap(node)
          return if !node || seen.any? { |previous| previous.equal?(node) }

          seen += [node]
          case node
          when Ast::M::VariableExpression then variable_info(node, seen)
          when Ast::M::CallNamedFunctionExpression then call_info(node, seen)
          else data_expression(node, seen)
          end
        end

        def data_expression(node, seen)
          case node
          when Ast::M::LiteralList then collection_info(node.values, :array, seen)
          when Ast::M::LiteralHash then hash_info(node, seen)
          else literal_info(node)
          end
        end

        def literal_info(node)
          if node.is_a?(Ast::M::LiteralRegularExpression)
            return { key: [:regexp, node.value.source, node.value.options], type: type('Regexp') }
          end

          known = @values.literal(node)
          return unless known

          value = known.first
          value_type = Puppet::Pops::Types::TypeCalculator.infer(value)
          return unless fits?(Registry::SCALAR, value_type) || value.nil?

          { key: [:literal, value.class.name, value.is_a?(Float) ? [value].pack('G') : value], type: value_type }
        end

        def collection_info(nodes, kind, seen)
          items = nodes.map { |item| expression(item, seen) }
          return unless items.all? { |item| item && fits?(Registry::DATA, item[:type]) }

          element_types = items.map { |item| item[:type] }
          value_type = Puppet::Pops::Types::TypeFactory.tuple(element_types)
          { key: [kind, items.map { |item| item[:key] }], type: value_type, items: items }
        end

        def hash_info(node, seen)
          entries = node.entries.map { |entry| [expression(entry.key, seen), expression(entry.value, seen)] }
          return unless entries.all? { |key, value| ordinary_entry?(key, value) }

          { key: [:hash, entries.map { |pair| pair.map { |item| item[:key] } }], type: type('Hash[String, Data]') }
        end

        def ordinary_entry?(key, value)
          key && value && fits?('String', key[:type]) && fits?(Registry::DATA, value[:type])
        end

        def call_name(node)
          functor = node.functor_expr
          return functor.cased_value if functor.is_a?(Ast::M::QualifiedReference)
          return functor.value if functor.is_a?(Ast::M::QualifiedName)

          nil
        end

        def call_info(node, seen)
          name = call_name(node)
          entry = Registry::FUNCTIONS[name]
          return unless entry
          return unless supported_call?(node, name)

          arguments = node.arguments.map { |argument| expression(argument, seen) }
          return unless arguments.all? && supported_arguments?(name, entry, arguments)

          { key: [:call, name, arguments.map { |argument| argument[:key] }], type: type(entry.first), name: name }
        end

        def supported_call?(node, name)
          !node.lambda && resolved?(name)
        end
      end

      # Limit dispatches and options independently of expression equivalence.
      module ArgumentForms
        def supported_arguments?(name, entry, arguments)
          signatures = entry[1]
          signatures = public_send(entry[2], arguments.length) if entry[2]
          signatures.any? do |signature|
            signature_matches?(signature, arguments)
          end && options_supported?(name, arguments)
        end

        def signature_matches?(signature, arguments)
          signature.length == arguments.length && signature.zip(arguments).all? do |expected, actual|
            fits?(expected, actual[:type])
          end
        end

        def format_arguments(count)
          count >= 2 ? [['String'] + Array.new(count - 1, Registry::SCALAR)] : []
        end

        def dig_arguments(count)
          count >= 2 ? [[Registry::COLLECTION] + Array.new(count - 1, 'Variant[String, Integer]')] : []
        end

        def merge_arguments(count)
          count >= 2 ? [Array.new(count, 'Hash[String, Data]')] : []
        end

        def options_supported?(name, arguments)
          return hash_conversion?(arguments.first) if name == 'Hash'

          return integer_options?(arguments) if name == 'Integer'
          return true unless name == 'regsubst' && arguments.length == 4

          flags = literal_argument(arguments.last)
          pattern = fits?('Regexp', arguments[1][:type]) ? /\AG?\z/ : /\A[GEIM]*\z/
          flags.is_a?(String) && flags.match?(pattern)
        end

        def integer_options?(arguments)
          arguments.one? || [2, 8, 10, 16].include?(literal_argument(arguments[1]))
        end

        def hash_conversion?(argument)
          return true if fits?('Hash[String, Data]',
                               argument[:type]) || fits?('Array[Tuple[String, Data]]', argument[:type])

          items = argument[:items]
          return false unless items&.length&.even?

          items.each_slice(2).all? { |key, _| fits?('String', key[:type]) }
        end

        def literal_argument(argument)
          argument[:key][2] if argument[:key].first == :literal
        end
      end

      # Verify function sources without loading or invoking module code.
      module Resolution
        def resolved?(name)
          @resolved.fetch(name) { @resolved[name] = implementation_known?(name) }
        end

        def implementation_known?(name)
          return false if ast.nodes.any? do |node, _|
            node.is_a?(Ast::M::NamedDefinition) && (node.name == name || node.name.split('::').last == name)
          end

          return stdlib_function?(name) if Registry::STDLIB_SOURCES.key?(name)

          conflicting_paths(name).empty?
        end

        def conflicting_paths(name)
          # A conflicting environment or module implementation makes resolution uncertain.
          return qualified_paths(name) if name.include?('::')

          @resolver.roots.flat_map do |root|
            patterns = ["*/functions/**/#{name}.pp", "*/lib/puppet/functions/**/#{name}.rb",
                        "*/lib/puppet/parser/functions/#{name}.rb", "functions/**/#{name}.pp",
                        "lib/puppet/functions/**/#{name}.rb", "lib/puppet/parser/functions/#{name}.rb"]
            patterns.flat_map { |pattern| Dir.glob(File.join(root, pattern)) }
          end
        end

        def qualified_paths(name)
          namespace, basename = name.split('::')
          @resolver.roots.flat_map do |root|
            paths = ["#{namespace}/functions/#{basename}.pp",
                     "#{namespace}/lib/puppet/functions/#{namespace}/#{basename}.rb",
                     "functions/#{namespace}/#{basename}.pp", "lib/puppet/functions/#{namespace}/#{basename}.rb"]
            paths.filter_map do |relative|
              file = File.join(root, relative)
              file if File.file?(file)
            end
          end
        end

        def stdlib_function?(name)
          root = @resolver.first_module_root('stdlib')
          return false unless root

          path, digest = Registry::STDLIB_SOURCES.fetch(name)
          expected = File.join(root, 'stdlib', path)
          return false unless source_matches?(expected, root, digest)
          return false unless conflicting_paths(name).all? { |file| file == expected }
          return true unless %w[stdlib::to_json stdlib::to_json_pretty stdlib::to_yaml].include?(name)

          stdlib_serialization_helper?(root)
        end

        def stdlib_serialization_helper?(root)
          helper, checksum = Registry::STDLIB_SOURCES.fetch('stdlib::rewrap_sensitive_data')
          expected_helper = File.join(root, 'stdlib', helper)
          source_matches?(expected_helper, root, checksum) &&
            conflicting_paths('stdlib::rewrap_sensitive_data').all? { |file| file == expected_helper }
        end

        def source_matches?(path, root, digest)
          @resolver.file_within_root?(path, root) && Digest::SHA256.file(path).hexdigest == digest
        rescue Errno::ENOENT, Errno::EACCES
          false
        end
      end

      # Group eager calls within one resource expression and prefer enclosing duplicates.
      module Detection
        def candidates(resource)
          ast.descendants(resource).grep(Ast::M::CallNamedFunctionExpression).filter_map do |node|
            next unless eager_use?(node, resource)

            info = expression(node)
            anchor_call(info, node) if info
          end
        end

        def anchor_call(info, node)
          span = expression_span(node)
          signature = span.all? ? code_signature(token_span(*span)) : nil
          info.merge(node: node, span: span, signature: signature)
        end

        def code_signature(span)
          span.reject { |part| PuppetLint::Data.formatting_tokens.include?(part.type) }.map do |part|
            [part.type == :STRING ? :SSTRING : part.type, part.value.dup]
          end
        end

        def eager_use?(node, resource)
          parents = @parents.fetch(node)
          return false if parents.any?(Ast::M::LambdaExpression)

          inner = parents.drop_while { |parent| !parent.equal?(resource) }.drop(1)
          inner.all? do |parent|
            [Ast::M::ResourceBody, Ast::M::AttributeOperation, Ast::M::LiteralList, Ast::M::LiteralHash,
             Ast::M::KeyedEntry, Ast::M::ParenthesizedExpression, Ast::M::CallNamedFunctionExpression].any? { |kind| parent.is_a?(kind) }
          end
        end

        def duplicate_groups(resource)
          groups = candidates(resource).group_by { |entry| entry[:key] }.values.select { |group| group.length > 1 }
          selected = nonoverlapping_groups(groups)
          selected.sort_by { |group| group.first[:node].offset }
        end

        def nonoverlapping_groups(groups)
          groups.sort_by { |group| -group.first[:node].length }.each_with_object([]) do |group, selected|
            remaining = group.reject { |entry| covered_call?(selected.flatten, entry) }
            selected << remaining if remaining.length > 1
          end
        end

        def covered_call?(selected, entry)
          selected.any? { |outer| contains?(outer[:node], entry[:node]) }
        end

        def contains?(outer, inner)
          outer.offset <= inner.offset && outer.offset + outer.length >= inner.offset + inner.length
        end

        def report(resource, group)
          first, second = group.map { |entry| entry[:node] }
          @edits << { resource: resource, group: group, anchor: resource_anchor(resource) }
          notify(:warning, message: "Repeated #{group.first[:name]}() call with identical arguments; " \
                                    'reuse a local variable. ' \
                                    "First occurrence at line #{first.line}.",
                           line: second.line, column: second.pos, edit: @edits.length - 1)
        end

        def resource_anchor(resource)
          line = @sections.fetch([resource.line, resource.pos], resource.line)
          tokens.find { |token| token.line == line && !%i[INDENT WHITESPACE].include?(token.type) }
        end
      end

      # Keep evaluation order, scope, names and original token anchors intact.
      module Safety
        def statement_resource?(resource)
          parents = @parents.fetch(resource)
          return false unless resource.bodies.one? && resource.form == 'regular'

          parents.all? { |parent| statement_parent?(parent) } &&
            parents.none? { |parent| parent.is_a?(Ast::M::HostClassDefinition) && parent.parent_class }
        end

        def statement_parent?(parent)
          [Ast::M::Program, Ast::M::BlockExpression, Ast::M::HostClassDefinition,
           Ast::M::ResourceTypeDefinition, Ast::M::IfExpression, Ast::M::CaseExpression,
           Ast::M::CaseOption].any? { |kind| parent.is_a?(kind) }
        end

        def evaluation_events(node)
          case node
          when Ast::M::LiteralList then node.values.flat_map { |item| evaluation_events(item) }
          when Ast::M::ParenthesizedExpression, Ast::M::TextExpression then evaluation_events(node.expr)
          when Ast::M::ConcatenatedString then node.segments.flat_map { |segment| evaluation_events(segment) }
          else evaluation_tail(node)
          end
        end

        def evaluation_tail(node)
          case node
          when Ast::M::LiteralHash
            node.entries.flat_map { |entry| evaluation_events(entry.key) + evaluation_events(entry.value) }
          when Ast::M::CallNamedFunctionExpression
            node.arguments.flat_map { |item| evaluation_events(item) } + [node]
          else [node]
          end
        end

        def resource_events(resource)
          body = resource.bodies.first
          ([body.title] + body.operations.map(&:value_expr)).flat_map { |node| evaluation_events(node) }
        end

        def safe_evaluation_order?(edit)
          events = resource_events(edit[:resource])
          first, last = event_bounds(events, edit[:group])
          return false unless first && last

          events.take(first).all? { |node| safe_predecessor?(node, edit) } &&
            events[first..last].all? { |node| expression(node) }
        end

        def event_bounds(events, group)
          [group.first, group.last].map { |entry| events.index { |node| node.equal?(entry[:node]) } }
        end

        def safe_predecessor?(node, edit)
          return false unless expression(node)
          return true unless node.is_a?(Ast::M::CallNamedFunctionExpression)

          contains?(edit[:group].first[:node], node) || @completed.any? { |outer| contains?(outer, node) }
        end

        def variable_name(group)
          name = group.first[:name]
          references = ast.references(group.first[:node])
          suffix = name.split('::').last.sub(/\Ato_/, '').downcase
          references.one? ? "#{references.first}_#{suffix}" : "#{suffix}_result"
        end

        def available_name?(name)
          !@introduced.include?(name) && ast.nodes.none? do |node, _|
            (node.is_a?(Ast::M::VariableExpression) && node.expr.value.split('::').last == name) ||
              (node.is_a?(Ast::M::Parameter) && node.name == name)
          end
        end

        def call_boundaries?(first, last, name)
          first.to_manifest == name && last.type == :RPAREN
        end

        def validated_span(entry)
          first, last = entry[:span]
          raise PuppetLint::NoFix unless first && last

          span = token_span(first, last)
          validate_span_contents(span)
          raise PuppetLint::NoFix unless code_signature(span) == entry[:signature]
          raise PuppetLint::NoFix unless call_boundaries?(first, last, entry[:name])

          span
        end

        def validate_span_contents(span)
          forbidden = %i[COMMENT SLASH_COMMENT MLCOMMENT HEREDOC_OPEN DQPRE DQPOST]
          raise PuppetLint::NoFix if span.any? { |token| forbidden.include?(token.type) }
          raise PuppetLint::NoFix if ignored_span?(span.first, span.last)
        end
      end

      # Prepare every replacement before modifying the native token stream.
      module Correction
        def replacement_plan(edit)
          raise PuppetLint::NoFix unless statement_resource?(edit[:resource]) && safe_evaluation_order?(edit)

          name = variable_name(edit[:group])
          raise PuppetLint::NoFix unless available_name?(name)

          build_plan(edit, name)
        end

        def build_plan(edit, name)
          spans = edit[:group].map { |entry| validated_span(entry) }
          anchor = edit[:anchor]
          validate_insertion(anchor, spans.last.last)
          replacements = spans.map { |span| [span, PuppetLint::Lexer.new.tokenise("$#{name}")] }
          { name: name, replacements: replacements, anchor: anchor,
            declaration: declaration_tokens(name, spans.first, anchor) }
        end

        def validate_insertion(anchor, last)
          raise PuppetLint::NoFix unless anchor && line_prefix(anchor).match?(/\A *\z/)
          raise PuppetLint::NoFix if ignored_span?(anchor, last)
          raise PuppetLint::NoFix if token_span(anchor, last).any? { |token| control_comment?(token) }
        end

        def declaration_tokens(name, span, anchor)
          indent = line_prefix(anchor)
          source = span.map(&:to_manifest).join
          raise PuppetLint::NoFix if source.include?("\n")

          comment = declaration_comment(anchor, indent)
          PuppetLint::Lexer.new.tokenise("#{comment}$#{name} = #{source}\n\n#{indent}")
        end

        def declaration_comment(anchor, indent)
          return '' unless adjacent_code(anchor, :prev_token)&.type == :LBRACE

          "# Reuse the repeated calculation in this block.\n#{indent}"
        end

        def apply_plan(plan)
          index = tokens.index(plan[:anchor])
          plan[:declaration].each_with_index { |token, offset| add_token(index + offset, token) }
          apply_replacements(plan)
          @introduced << plan[:name]
        end

        def apply_replacements(plan)
          plan[:replacements].each do |span, replacement|
            replace_tokens(span.first, span.last, replacement)
          end
        end
      end

      include SectionLayout
      include TokenHelpers
      include Types
      include Expressions
      include ArgumentForms
      include Resolution
      include Detection
      include Safety
      include Correction

      def check
        prepare_analysis
        ast.each_node(Ast::M::ResourceExpression) do |resource, _|
          duplicate_groups(resource).each { |group| report(resource, group) }
        end
      end

      def prepare_analysis
        @source = manifest_lines.join("\n")
        @types = {}
        @resolved = {}
        @introduced = []
        @completed = []
        @edits = []
        @values = ParameterSource.new(ast)
        @resolver = ModuleResolver.new
        prepare_positions
      end

      def prepare_positions
        @parents = {}.compare_by_identity
        ast.nodes.each { |node, parents| @parents[node] = parents }
        @sections = section_starts
      end

      def fix(problem)
        edit = @edits.fetch(problem[:edit])
        apply_plan(replacement_plan(edit))
        @completed.concat(edit[:group].map { |entry| entry[:node] })
      end
    end
    PuppetLint.new_check(:project_duplicate_function_calls) { include DuplicateFunctionCalls }
  end
end
