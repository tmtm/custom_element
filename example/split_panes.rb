class SplitPanes < CustomElement
  style = JSrb.document.create_element('style')
  style.text_content = <<~CSS
    split-panes {
        display: block;
        overflow: scroll;
    }
    split-pane {
        position: absolute;
        display: block;
        overflow: scroll;
    }
    split-splitter {
        position: absolute;
        display: block;
        align-items: center;
        background-color: white;
        div.knob {
            display: inline-block;
            position: absolute;
            vertical-align: middle;
            top: 0;
            right: 0;
            bottom: 0;
            left: 0;
            margin: auto;
            background-color: #ddd;
            user-select: none;
        }
        div.knob-vertical {
            width: 4px;
            height: 50px;
        }
        div.knob-horizontal {
            width: 50px;
            height: 4px;
        }
    }
    split-splitter.vertical {
        cursor: col-resize;
        width: 6px
    }
    split-splitter.horizontal {
        cursor: row-resize;
        height: 6px
    }
  CSS
  JSrb.document.query_selector('head').append(style)

  def connected_callback
    if self.get_attribute('vertical')
      @mode = :vertical
      @dimension = :width
      @client_dimension = :clientWidth
    else
      @mode = :horizontal
      @dimension = :height
      @client_dimension = :clientHeight
    end

    panes = self.query_selector_all(':scope > split-pane').entries
    splitters = []
    (panes.size - 1).times.each do |i|
      splitter = JSrb.document.create_element('split-splitter')
      splitter.class_name = @mode.to_s
      splitter.add_event_listener('mousedown'){|ev| @splitter = i if ev.buttons == 1}
      splitters.push splitter
      panes[i].after splitter
    end
    splitter_size = splitters.sum(&@client_dimension)
    self.style[:"min#{@dimension.upcase}"] = "#{(panes.size * 20) + splitter_size}px" unless self.style[:"min#{@dimension.upcase}"]
    panes_size = self[@client_dimension] - splitter_size
    size = panes_size / panes.size
    panes[0..-2].each do |pane|
      pane.style[@dimension] = "#{size}px"
    end
    panes.last.style[@dimension] = "#{panes_size - (size * (panes.size - 1))}px"

    @panes = panes
    @splitters = splitters

    reset_pane_position(self[@client_dimension])

    self.add_event_listener('mouseup'){@splitter = nil}
    self.add_event_listener('mousemove') do |ev|
      next if !@splitter || ev.buttons != 1
      i = @splitter
      if @mode == :horizontal
        d = ev.movement_y
        rect = splitters[i].get_bounding_client_rect
        next if (d > 0 && ev.y < rect.y) || (d < 0 && ev.y > rect.y + rect[@dimension])
      else
        d = ev.movement_x
        rect = splitters[i].get_bounding_client_rect
        next if (d > 0 && ev.x < rect.x) || (d < 0 && ev.x > rect.x + rect[@dimension])
      end
      h0 = panes[i][@client_dimension] + panes[i+1][@client_dimension]
      h1 = panes[i][@client_dimension] + d
      h2 = panes[i+1][@client_dimension] - d
      if h1 < 20
        h1 = 20
        h2 = h0 - 20
      end
      if h2 < 20
        h2 = 20
        h1 = h0 - 20
      end
      panes[i].style[@dimension] = "#{h1}px"
      panes[i+1].style[@dimension] = "#{h2}px"
      reset_pane_position(self[:@client_dimension])
    end

    resize_observer = JSrb.global[:ResizeObserver].new do |entries|
      entries.each do |entry|
        new_size = entry.border_box_size[0].block_size
        reset_pane_position(new_size)
      end
      nil
    end
    resize_observer.observe(self.js_object)
  end

  def reset_pane_position(new_size)
    total = 0
    if @mode == :vertical
      another_dimension = :height
      another_size = self.client_height
      pos = :left
    else
      another_dimension = :width
      another_size = self.client_width
      pos = :top
    end
    @panes[0..-2].each_with_index do |pane, i|
      pane.style[pos] = "#{total}px"
      pane.style[another_dimension] = "#{another_size}px"
      total += pane[@client_dimension]
      @splitters[i].style[pos] = "#{total}px"
      @splitters[i].style[another_dimension] = "#{another_size}px"
      total += @splitters[i][@client_dimension]
    end
    @panes.last.style[pos] = "#{total}px"
    @panes.last.style[another_dimension] = "#{another_size}px"
    last_pane_size = new_size - total
    last_pane_size = last_pane_size.clamp(20..)
    @panes.last.style[@dimension] = "#{last_pane_size}px"
  end

  def disconnected_callback
    p :disconnected
  end

  def adopted_callback
    p :adopted
  end

  def attribute_changed_callback(name, old, new)
    p :attribute_changed, name, old, new
  end
end

class SplitPane < CustomElement
  def connected_callback
    resize_observer = JSrb.global[:ResizeObserver].new do |entries|
      entries.each do |entry|
        new_height = entry.border_box_size[0].block_size
        if self.children.first
          self.children.first.style.width = '100%'
          self.children.first.style.height = "#{new_height}px"
        end
      end
      nil
    end
    resize_observer.observe(self.js_object)
  end

  def disconnected_callback
    p :disconnected
  end

  def adopted_callback
    p :adopted
  end

  def attribute_changed_callback(name, old, new)
    p :attribute_changed, name, old, new
  end
end

class SplitSplitter < CustomElement
  def connected_callback
    knob = JSrb.document.create_element('div')
    knob.class_name = "knob knob-#{self.class_name}"
    self.append knob
  end

  def disconnected_callback
    p :disconnected
  end

  def adopted_callback
    p :adopted
  end

  def attribute_changed_callback(name, old, new)
    p :attribute_changed, name, old, new
  end
end
CustomElement.define 'split-panes', SplitPanes
CustomElement.define 'split-pane', SplitPane
CustomElement.define 'split-splitter', SplitSplitter
