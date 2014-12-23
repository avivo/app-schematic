##
# Basic aliases

alias :edge :e

class Hash
  alias :+ :merge
end

## 
# Node / Edge creation helpers and aliases

# labeled('a', '->', 'b', {})
def labeled(subj, pred, objs, opts={})
  e(subj, objs, {label: pred, fontsize: 12} + opts)
end
alias :el :labeled

def cycle(subj, label, opts={})
  labeled(subj, label, subj, opts)
end
alias :c :cycle

def action(n1, label, n2, opts={})
  labeled(n1, label, n2, {color: action_color, style: :dashed, arrowhead: :vee, fontcolor: action_color}.merge(opts))
end
alias :a :action

def action_cycle(subj, label, opts={})
  action(subj, label, subj, opts)
end
alias :ac :action_cycle

def modal(subj, obj, opts={})
  e(subj, n(obj, modal_node), modal_edge + opts)
end
def modals(subj, objs, opts={})
  e(subj, ns(objs, modal_node), modal_edge + opts)
end


def event(evnt, type, result, opts={})
  el(n(evnt, event_node), type, result, event_edge + opts)
end

def nav(from, tos)
  edge(n(from, shape: :none), tos, associated)
end

def leave(from, type, to, opts={})
  el(from, type, n(to, leave_node), leave_edge + opts)
end

## 
# Styles for nodes and edges

def backlink; {color: :blue} end

def action_color; :crimson end
def action_node; {fontcolor: action_color} end
def modal_node; {color: :purple, shape: :box, style: :dashed} + action_node end
def modal_edge; {color: :purple, style: :dashed, arrowhead: :none, fontcolor: :purple} end

def graph_defaults; {fontsize: 30, labelloc: "t", rankdir: "LR"} end
def everywhere; {color: :darkorange, fillcolor: :orange, shape: :box, style: :filled} end
def anywhere; everywhere + {color: :coral3, fillcolor: :coral2} end

def connected_views; {arrowhead: :dotnormal, color: 'green4:black:green4'} end
def connected_views; {arrowhead: :dotnormal} end

def type_cluster;  {fontsize: 18, style: 'rounded, filled', color: :gray90} end

def event_node; {color: :lightblue, style: :filled, shape: :polygon, margin: '0', distortion: -0.2} end
def event_edge; {color: :lightblue, penwidth: 3, arrowhead: :open, fontcolor: :lightblue4} end

def associated; {style: :dotted, arrowhead: :none} end

def leave_node; {color: :plum, style: :filled, shape: :polygon, margin: '0', distortion: +0.1} end
def leave_edge; {fontcolor: :plum, color: :plum, penwidth: 3, arrowhead: :open, fontcolor: :plum4} end

## 
# Subgraphs with programmatically defined styles 

def use(num_or_sym, &block)
  if num_or_sym.is_a? Symbol
    n = case num_or_sym
        when :hourly
          8
        when :daily
          6
        when :often
          4
        when :rarely
          1
        else
          raise 'Invalid use!!!'
        end
  else
    n = num_or_sym
  end
  node_opts = {penwidth: n}

  return node_opts if !block

  subgraph(node: node_opts) do |sg|
    block.call
  end  
end

def use_edge(num_or_sym, &block)
  if num_or_sym.is_a? Symbol
    n = case num_or_sym
        when :hourly
          5
        when :daily
          3
        when :often
          2
        when :rarely
          1
        else
          raise 'Invalid use!!!'
        end
  else
    n = num_or_sym
  end
  edge_opts = {penwidth: n}

  return edge_opts if !block

  subgraph(edge: edge_opts) do |sg|
    block.call
  end  
end


##
# General helpers

# Quick hack
def titlify(s)
  s.split(/[ _]/).map(&:capitalize).join(' ')
end

