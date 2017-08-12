module Trailblazer
  class Activity
    # Only way to build an Activity.
    def self.from_wirings(wirings, &block)
      start_evt  = Circuit::Start.new(:default)
      start_args = [ start_evt, { type: :event, id: [:Start, :default] } ]

      start      = block ? Graph::Start( *start_args, &block ) : Graph::Start(*start_args)

      wirings.each do |wiring|
        start.send(*wiring)
      end

      new(start)
    end

    def self.merge(activity, wirings)
      graph = activity.graph

      # TODO: move this to Graph
      # replace the old start node with the new one that's created in ::from_wirings.
      cloned_graph_ary = graph[:graph].collect { |node, connections| [ node, connections.clone ] }
      old_start_connections = cloned_graph_ary.delete_at(0)[1] # FIXME: what if some connection goes back to start?

      from_wirings(wirings) do |start_node, data|
        cloned_graph_ary.unshift [ start_node, old_start_connections ] # push new start node onto the graph.

        data[:graph] = ::Hash[cloned_graph_ary]
      end
    end

    def initialize(graph)
      @graph       = graph
      @start_event = @graph[:_wrapped]
      @circuit     = to_circuit(@graph) # graph is an immutable object.
    end

    def call(start_at, *args)
      @circuit.( @start_event, *args )
    end

    def end_events
      @circuit.to_fields[1]
    end

    # @private
    attr_reader :circuit
    # @private
    attr_reader :graph

    private

    def to_circuit(graph)
      end_events = graph.find_all { |node| graph.successors(node).size == 0 } # Find leafs of graph.
        .collect { |n| n[:_wrapped] } # unwrap the actual End event instance from the Node.

      Circuit.new(graph.to_h( include_leafs: false ), end_events, {})
    end

    class Introspection
      # @param activity Activity
      def initialize(activity)
        @activity = activity
        @graph    = activity.graph
        @circuit  = activity.circuit
      end

      # Find the node that wraps `task` or return nil.
      def [](task)
        @graph.find_all { |node| node[:_wrapped] == task  }.first
      end
    end
  end
end
