#!/usr/bin/env ruby
require_relative 'core'
require_relative 'app-dsl'
require 'pp'

all_platforms = [:mobile, :desktop]
all_roles = [:visitor, :member]

main = proc do
  flow_opts = [
               {roles: [:visitor]},
               {roles: [:member]},
              ]
  
  flow_opts = flow_opts.map do |o|
    all_platforms.map do |p|  
    	o.merge(platform: p)
    end
  end
  flow_opts = [{just_legend: true}] + flow_opts
  flows = flow_opts.flatten.map {|o| flow_content(o)}
  
  case :svg
  when :pdf
    render(flows, 'flow', 'pdf')
    refresh_preview  
  when :svg
   render_svgs(flows, 'flow')
   # `open flow.html`
   refresh_chrome_tab
  end
end

 
## These may not all be separate pages/screens, but simply separate views, which contain the next level.
def flow_content(opts = {})
  #-- Setup option shortcuts
  platform = opts[:platform] || :mobile
  roles = opts[:roles] || []

  graph(opts) do |g|
    #-- Configure graph
    g.opts[:created_at] = Time.now.strftime('%-I:%M:%S %p on %-m/%d')
    title = "#{platform.capitalize} "
    title += if roles.empty? then 'No roles' else roles.join(', ') end
    g.opts[:title] = titlify(title)
    label = "<table border='0'><tr><td>#{g.opts[:title]}</td></tr>"
    label += "<tr><td><font point-size='16'>#{g.opts[:created_at]}</font></td></tr></table>"

    # Uses the *undocumented* 'newrank=true' described here: https://stackoverflow.com/questions/6824431/placing-clusters-on-the-same-rank-in-graphviz/18410951
    g.opts[:graph] = graph_defaults.merge(shape: :plaintext, newrank: true, label: label, splines: true, overlap: false, concentrate: false, compound: true)
    g.opts[:node] = {shape: :Mrecord, style: :rounded, fontname: "ProximaNova-Light", color: :green}

    #-- Create Legend
    if opts[:legend] or opts[:just_legend]
      legend = subgraph(name: :cluster_legend, graph: graph_defaults.merge(label: 'Legend', style: :filled, color: :gray80, fillcolor: :gray95)) do |sg|      
        n('Screen')
        n('Always on every screen', everywhere)
        n('Can be on any screen', anywhere)
        el('1', 'normal navigation', '2')
        action('3', 'action', '4')
        el('5', 'connected views', '6', connected_views)
        modal('7', 'Modal')
        nav('Nav structure', '8')
        event('Event', 'notif type', '9')
        leave('10', 'effect', 'External view')
      end
      if opts[:just_legend]
        g.opts[:graph][:label] = ''
        next 
      end
    end
    
    #-- Utility variables
    #-- Core Navigation
    
    case platform 
    when :desktop
      nav('Top Bar', [n(e('Support (Link)', 'Support'), everywhere),
                      'Home (Link)'])
    when :mobile
      n('Menu', everywhere)
    end

    if roles.member? :visitor
      e('Home', 'Signup')
      case platform 
      when :desktop
        nav('Top Bar', [e(n('Login (Link)', everywhere), 'Login'),
                        e(n('Signup (Link)', everywhere), 'Signup')])
      when :mobile
        e('Menu', ['Home', 'Support', 'Login', 'Signup'])
      end
    end	    

    use(:hourly) do
      e(n('Home (Link)', everywhere), 'Home')
    end

    if roles.member? :member
      n('Anywhere', shape: :none)
      ns(['Critical Alerts', 'Flash'], anywhere)
      
      use(:hourly) do
        ns([e('Update (Link)', 'Updates List'), 
            e('Todo (Link)', 'Todo List')], 
           everywhere)    
        e(['Updates List', 'Todo List'], n('Anywhere', shape: :none))
      end

      e(['Critical Alerts'], 'Anywhere')
      e('Anywhere', 'Flash')
      
      case platform 
      when :desktop
        nav('Top Bar',
            ['Update (Link)',
             'Todo (Link)',
             n('Logout (Action)', everywhere + action_node),
             edge(n('Settings (Link)', everywhere),
                  'Settings'), 
             edge(n('Profile (Link)', everywhere),
                  'Profile')])
      when :mobile
        e('Menu', [n('Logout (Action)', action_node), 'Settings', 'Profile', 'Support'])
      end
    end
    
    #-- Layout hints
    #-- Other Navigation
    #-- Events
    #-- Actions
    #-- Support + Settings
    e('Support', ['FAQ', 'Documentation'])
    leave('Support', 'email', 'Email app')
    if roles.member? :member
      action_cycle('Settings', "edit notifs/sounds/push\nchange passwd")
    end
  end
end


if __FILE__ == $0
  main.call
end
