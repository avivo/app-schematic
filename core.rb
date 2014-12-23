#!/usr/bin/env ruby
#
# To run on a separate file with auto-generate on save, put in directory with e.g. `example.rb`, make executable, and use: `fswatch -o *.rb | xargs -n1 -I{} ./example.rb`
# To just run sample code, just run this file: `ruby core.rb`.

# TODO fix counter hack
COUNT = [0]

class Graph
  attr_accessor :opts
  # includes nodes in all subgraphs
  attr_accessor :nodes
  # only nodes *not* declared explicitly in this graph (just in subgraphs)
  attr_accessor :nodes_declared_subgraph
  # only nodes declared explicitly in this graph
  attr_accessor :nodes_declared_here

  def initialize(opts = nil) 
    @nodes = {}
    @nodes_declared_subgraph = {}
    @nodes_declared_here = {}
    @edge_str = ''
    @subgraph_str = ''
    @opts = opts || {} 
    defaults = {type: 'digraph', 
                name: 'g' + COUNT[0].to_s, 
                filename: 'flow'}
    @opts = defaults.merge(@opts)
    COUNT[0] += 1
  end

  def expand_opts(opts)
    return '[]' if opts.nil? or opts.empty?

    s = '['
    opts.each do |k,v|
      if !([:id, :type].member?(k.to_sym))
        s += k.to_s + '='

        if v.is_a? String
          v = labelify(v) if k == :label
          if v =~ /<.*>/
            s += '<' + v + '>'
          else
            s += '"' + v + '"'
          end
        else
          s += v.to_s
        end
        s += ' '
      end
    end
    s + ']'
  end

  def n(node, n_opts = {})
    node = n_helper(node, n_opts)
    nodes_declared_here[node[:id]] = node
    node
  end

  def n_helper(node, n_opts = {})   
    if node.is_a? String
      node = {label: node}
    elsif node.is_a? Array
      raise "don't allow multiple nodes now: #{node}"
      # return node.map{|elt| n(elt, n_opts)}
    else
      node = node.dup
    end
    
    # creates a canonical id from the label if it doesn't already exist
    node[:id] ||= idify(node[:label])
    # type is just used as debugging info if needed
    node[:type] = :node
    # merges in custom opts if relevant
    node.merge!(n_opts)

    if @nodes[node[:id]].nil? #or declared
      @nodes[node[:id]] = node
    else
      node = @nodes[node[:id]].merge!(node)
    end
    node
  end

  def node_strs
    if opts[:root]
      nodes_to_write = nodes.reject{|n| nodes_declared_subgraph.member? n}
    else
      nodes_to_write = nodes_declared_here
    end

    nodes_to_write.map do |id, node|
      "    #{id} #{expand_opts(node)};\n"
    end.join
  end

  def is_node?(obj)
    obj.is_a? Hash and obj[:type] == :node
  end

  # e('a', 'b', {})
  def e(froms, tos, e_opts={})
    opts_string = e_opts.map{|k,v| "#{k}=\"#{v}\" "}.join

    tos = [tos] if !tos.is_a? Array
    froms_list = if !froms.is_a? Array then [froms] else froms end

    froms_list.each do |from|
      tos.each do |to|
        @edge_str.concat "    #{n_helper(from)[:id]} -> #{n_helper(to)[:id]} [#{opts_string}];\n"
      end
    end
    froms
  end

  def add_subgraph(subgraph)
    nodes.merge!(subgraph.nodes)
    nodes_declared_subgraph.merge!(subgraph.nodes_declared_here)
    @subgraph_str += subgraph.dot_string.gsub(/^/, "    ")
  end

  def dot_string
    s = <<-STR.gsub(/^ {4}/, '')
    #{opts[:type]} #{opts[:name]} {
        graph #{expand_opts(opts[:graph])};
        node #{expand_opts(opts[:node])}
        edge #{expand_opts(opts[:edge])}

    STR
    s += @subgraph_str + node_strs + "\n" + @edge_str + (opts[:eof] || '') + "}\n\n"
  end
end

def idify(s)
  s.split(/[^\w]/).map(&:capitalize).join
end

# anything after a + is ignored
def labelify(s)
  s.gsub(/\+.*/,'')
end

# hack...
def render(graphs, filename = 'flow', filetype = 'pdf')
  if graphs.is_a? Array
    dot_string = graphs.map(&:dot_string).join
  else
    dot_string = graphs.dot_string 
  end

  File.write("#{filename}.dot", dot_string)

  `dot -T#{filetype} #{filename}.dot -o #{filename}.#{filetype}` 
  
  puts "Saved #{filename}.#{filetype} on #{Time.now}"
end
  

def render_svgs(graphs, filename = 'flow')
  require 'nokogiri'

  toc = []
  graph_elts = []
  
  graphs.each do |g|    
    id = title = g.opts[:title]
    toc << "<li><a href='##{id}'>#{title}</a></li>"
    
    render(g, filename, 'svg')
    generated_svg = `cat #{filename}.svg`
    parsed_svg = Nokogiri::HTML.parse(generated_svg).at_xpath('//svg')
    parsed_svg['width'] = '100%'
    
    svg = parsed_svg.to_html

    graph_elts << "<div id='#{id}' style='padding-bottom:80px'>#{svg}</div>"
  end


  html = <<-HTML.gsub(/^ {2}/, '')
  <!DOCTYPE html>
  <html>
    <body>
      <ul>
        #{toc.join}
      </ul>
      <div>
        #{graph_elts.join}
      </div>
    </body>
  <html>
  HTML
  
  File.write("#{filename}.html", html)
  
  puts "Saved #{filename}.html on #{Time.now}"
end


### This allows a shorthand syntax to be used for building graphs

Holder = []

def graph(opts = {}, &block)
  g = Graph.new({root: true}.merge(opts))
  Holder.push(g)
  block.call(g)
  Holder.pop # should be g
end


# Remember holder needs to have a Graph (using the graph block) or it will fail
def e(*args) Holder.last.e(*args) end 
def e2(*args) Holder.last.e2(*args) end
def n(*args) Holder.last.n(*args) end
def ns(nodes, opts = {}) nodes.map{|node| n(node, opts)} end 


# A subgraph is treated as a cluster if it's name start with 'cluster'
# (yes a hack, but from the dot language)
def subgraph(opts = {}, &block)
  opts = {type: 'subgraph'}.merge(opts)
  Holder.last.add_subgraph(graph(opts, &block))
end


# Hack to get Preview.app to refresh from http://hints.macworld.com/article.php?story=2006010200141989
# `open ___` steals focus which may not always be ideal
def refresh_preview
  s = <<-APPLE_SCRIPT
  set frontApp to (path to frontmost application as Unicode text)
  if "Preview" is in frontApp then
    tell application "Finder" to activate
    tell application "Preview" to activate
  else
    tell application "Preview" to activate
    tell application frontApp to activate
  end if
  APPLE_SCRIPT
  `echo '#{s}' | osascript`
end

def refresh_chrome_tab
  s = <<-APPLE_SCRIPT
  tell application "Google Chrome" to tell the active tab of its first window
    reload
  end tell
  APPLE_SCRIPT
  `echo '#{s}' | osascript`
end

if __FILE__ == $0
  require 'pp'
  g1 = graph do |g|
    g.opts[:graph] = {label: 'graph label!', fontsize: 30, labelloc: 't'}
    n 'bla'
    n 'ABC', color: :blue, style: 'filled'
    n 'ABc', fillcolor: :green
    # Note the case insensitive unique label names (properties just get combined)
    e('1','2')
    e('a','c', label: 'edge label!')
    subgraph do |c|
      c.opts[:graph] = {label: "subgraph label!", fontsize: 15}
      c.opts[:name] = 'cluster0'
      n 'moo'
      subgraph do |c|
        c.opts[:name] = 'cluster1'
        n 'boo'
      end
    end

    subgraph do |c|
      c.opts[:name] = 'aaa'
      c.opts[:graph] = {rank: :same, label: "dad", fontsize: 15}
      n 'goo'
    end

    e 'boo', 'goo'
  end

  render(g1)
  refresh_preview
end
