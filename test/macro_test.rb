require "test_helper"
#- test
# macro [ task, {name} ]
# macro [ task, {name}, { alteration: } ] # see task_wrap_test.rb
# macro [ task, {name}, { alteration: }, {task_outputs} ] # for eg. nested

class MacroTest < Minitest::Spec
  MacroB = ->(direction, options, flow_options) do
    options[:B] = true # we were here!

    [ options[:MacroB_return], options, flow_options ]
  end

  class Create < Trailblazer::Operation
    step :a
    step( task: MacroB, node_data: { id: :MacroB }, outputs: { "Allgood" => { role: :success }, "Fail!" => { role: :failure }, "Winning" => { role: :pass_fast } } )
    step :c

    def a(options, **); options[:a] = true end
    def c(options, **); options[:c] = true end
  end

  # MacroB returns Allgood and is wired to the :success edge (right track).
  it { Create.( {}, MacroB_return: "Allgood" ).inspect(:a, :B, :c).must_equal %{<Result:true [true, true, true] >} }
  # MacroB returns Fail! and is wired to the :failure edge (left track).
  it { Create.( {}, MacroB_return: "Fail!" ).inspect(:a, :B, :c).must_equal %{<Result:false [true, true, nil] >} }
  # MacroB returns Winning and is wired to the :pass_fast edge.
  it { Create.( {}, MacroB_return: "Winning" ).inspect(:a, :B, :c).must_equal %{<Result:true [true, true, nil] >} }

  #- user overrides :outputs
  class Update < Trailblazer::Operation
    macro = { task: MacroB, node_data: { id: :MacroB }, outputs: { "Allgood" => { role: :success }, "Fail!" => { role: :failure }, "Winning" => { role: :pass_fast } } }

    step :a
    step macro, outputs: { "Allgood" => { role: :failure }, "Fail!" => { role: :success }, "Winning" => { role: :fail_fast } }
    step :c

    def a(options, **); options[:a] = true end
    def c(options, **); options[:c] = true end
  end

  # MacroB returns Allgood and is wired to the :failure edge.
  it { Update.( {}, MacroB_return: "Allgood" ).inspect(:a, :B, :c).must_equal %{<Result:false [true, true, nil] >} }
  # MacroB returns Fail! and is wired to the :success edge.
  it { Update.( {}, MacroB_return: "Fail!" ).inspect(:a, :B, :c).must_equal %{<Result:true [true, true, true] >} }
  # MacroB returns Winning and is wired to the :fail_fast edge.
  it { Update.( {}, MacroB_return: "Winning" ).inspect(:a, :B, :c).must_equal %{<Result:false [true, true, nil] >} }
end
