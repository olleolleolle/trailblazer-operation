require "test_helper"

# Tests
# ---  step ->(*) { snippet }
# ---  step Callable
# ---  step :method
# ---  step MyMacro
class StepTest < Minitest::Spec
  class Callable
    def self.call(options, b:nil, **)
      options["b"] = b
    end
  end

  module Implementation
    module_function
    def c(options, c:nil, **)
      options["c"] = c
    end
  end

  MyMacro = ->( direction, options, flow_options ) do
    options["e"] = options[:e]

    [ direction, options, flow_options ]
  end

  class Create < Trailblazer::Operation
    step ->(options, a:nil, **) { options["a"] = a }
    step Callable
    step Implementation.method(:c)
    step :d
    step( { task: MyMacro, node_data: { id: "MyMacro" } } ) # doesn't provide `runner_options` and `outputs`.

    def d(options, d:nil, **)
      options["d"] = d
    end
  end

  it { Create.({}, a: 1, b: 2, c: 3, d: 4, e: 5).inspect("a", "b", "c", "d", "e").must_equal "<Result:true [1, 2, 3, 4, 5] >" }

  it { Trailblazer::Operation::Inspect.(Create).gsub(/0x.+?step_test.rb/, "").must_equal %{[>#<Proc::29 (lambda)>,>StepTest::Callable,>#<Method: StepTest::Implementation.c>,>d,>MyMacro]} }
  # poor test to make sure we pass debug information to Activity.

  # it { puts Create["__activity__"].to_fields.last.inspect }
  it { Create["__activity__"].graph.find_all(:d).first[:id].must_equal :d }

  #---
  #- :before, :after, :replace, :delete, :override
  class A < Trailblazer::Operation
    step :a!
    def a!(options, **); options["a"] = 1; end
  end

  class B < A
    step :b!, before: :a!
    step :c!, before: :a!
    step :d!, after:  :b!
  end

  it { Trailblazer::Operation::Inspect.(B).must_equal %{[>b!,>d!,>c!,>a!]} }

  class C < B
    step :e!, replace: :c!
    step "nil", delete: :d!
  end

  it { Trailblazer::Operation::Inspect.(C).must_equal %{[>b!,>e!,>a!]} }

  #---
  #- override: true
  class D < Trailblazer::Operation
    step :a!
    step :add!
    step :add!, id: :another_add!#, override: true

    def a!(options, **);   options["a"] = []; end
    def add!(options, **); options["a"] << :b; end
  end

  it { Trailblazer::Operation::Inspect.(D).must_equal %{[>a!,>add!,>another_add!]} }
  it { D.().inspect("a").must_equal %{<Result:true [[:b, :b]] >} }

  class E < Trailblazer::Operation
    step :a!
    step :add!
    step :add!, override: true

    def a!(options, **);   options["a"] = []; end
    def add!(options, **); options["a"] << :b; end
  end

  it { Trailblazer::Operation::Inspect.(E).must_equal %{[>a!,>add!]} }
  it { E.().inspect("a").must_equal %{<Result:true [[:b]] >} }

  #- with proc
  class F < Trailblazer::Operation
    step :a!
    step ->(options, **) { options["a"] << :b }, id: "add"
    step ->(options, **) { options["a"] << :b }, replace: "add", id: "add!!!"

    def a!(options, **);   options["a"] = []; end
  end

  it { Trailblazer::Operation::Inspect.(F).must_equal %{[>a!,>add!!!]} }
  it { F.().inspect("a").must_equal %{<Result:true [[:b]] >} }

  #- with macro
  class G < Trailblazer::Operation
    MyMacro1 = ->(direction, options, flow_options) { options["a"] << :b; [ direction, options, flow_options ] }
    MyMacro2 = ->(direction, options, flow_options) { options["a"] << :b; [ direction, options, flow_options ] }
    # MyMacro3 = ->(direction, options, flow_options) { options["a"] << :b; [ direction, options, flow_options ] }

    step :a!
    step( { task: MyMacro1, node_data: { id: "add"} })
    puts "yo"
    step( { task: MyMacro2, node_data: { id: "add"} }, replace: "add")
    # step [ MyMacro3, {id: "add"}, {} ], override: true

    def a!(options, **);   options["a"] = []; end
  end

  it { Trailblazer::Operation::Inspect.(G).must_equal %{[>a!,>add]} }
  it { G.().inspect("a").must_equal %{<Result:true [[:b]] >} }

  #- with inheritance
  class H < Trailblazer::Operation
    step :a!
    step :add!

    def a!(options, **);   options["a"] = []; end
    def add!(options, **); options["a"] << :b; end
  end

  class Hh < H
    step :_add!, replace: :add!

    def _add!(options, **); options["a"] << :hh; end
  end

  it { Trailblazer::Operation::Inspect.(Hh).must_equal %{[>a!,>_add!]} }
  it { Hh.().inspect("a").must_equal %{<Result:true [[:hh]] >} }

  #- inheritance unit test
  class I < Trailblazer::Operation
    step :a
  end

  class Ii < I
    step :a, override: true
  end

  it { Ii["__activity__"].circuit.instance_variable_get(:@map).size.must_equal 2 }

  #---
  #-
  # not existent :name
  it do
    err = assert_raises Trailblazer::Operation::Railway::Sequence::IndexError  do
      class E < Trailblazer::Operation
        step :a, before: "I don't exist!"
      end
    end

    err.inspect.must_equal "#<Trailblazer::Operation::Railway::Sequence::IndexError: I don't exist!>"
  end

  #---
  #- :name
  #-   step :whatever, id: :validate
  class Index < Trailblazer::Operation
    step :validate!, id: "my validate"
    step :persist!
    step( { task: MyMacro, node_data: { id: "I win!" } })
    step( { task: MyMacro, node_data: { id: "I win!" } }, id: "No, I do!")
  end

  it { Trailblazer::Operation::Inspect.(Index).must_equal %{[>my validate,>persist!,>I win!,>No, I do!]} }

  #---
  #- inheritance
  class New < Create
  end

  it { Trailblazer::Operation::Inspect.(New).gsub(/0x.+?step_test.rb/, "").must_equal %{[>#<Proc::29 (lambda)>,>StepTest::Callable,>#<Method: StepTest::Implementation.c>,>d,>MyMacro]} }

  class Update < Create
    step :after_save!
  end

  it { Trailblazer::Operation::Inspect.(Update).gsub(/0x.+?step_test.rb/, "").must_equal %{[>#<Proc::29 (lambda)>,>StepTest::Callable,>#<Method: StepTest::Implementation.c>,>d,>MyMacro,>after_save!]} }
end

#---
#- Macros with the old `input` arg.
#  step [ ->(input, options) { } ]
class StepWithDeprecatedMacroTest < Minitest::Spec # TODO: remove me in 2.2.
  class Create < Trailblazer::Operation
    MyOutdatedMacro = ->(input, options) {
      options["x"] = input.class
    }

    class AnotherOldMacro
      def self.call(input, options)
        options["y"] = input.class
      end
    end

    step [ MyOutdatedMacro, id: :outdated ]
    step [ AnotherOldMacro, id: :oldie ]
  end

  it { Trailblazer::Operation::Inspect.(Create).gsub(/0x.+?step_test.rb/, "").must_equal %{[>outdated,>oldie]} }
  it { Create.().inspect("x", "y").must_equal %{<Result:true [StepWithDeprecatedMacroTest::Create, StepWithDeprecatedMacroTest::Create] >} }
end

