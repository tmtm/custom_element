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
        width: 6px;
        cursor: col-resize;
        background-color: white;
        div.knob {
            position: absolute;
            top: 50%;
            background-color: #ddd;
            width: 4px;
            height: 50px;
            margin: auto;
            user-select: none;
        }
    }
  CSS
  JSrb.document.query_selector('head').append(style)

  def connected_callback
    panes = self.query_selector_all(':scope > split-pane').entries
    splitters = []
    (panes.size - 1).times.each do |i|
      splitter = JSrb.document.create_element('split-splitter')
      splitter.add_event_listener('mousedown'){|ev| @splitter = i if ev.buttons == 1}
      splitters.push splitter
      panes[i].after splitter
    end
    splitter_width = splitters.sum(&:client_width)
    self.style.min_width = "#{(panes.size * 20) + splitter_width}px" unless self.style.min_width
    panes_width = self.client_width - splitter_width
    width = panes_width / panes.size
    panes[0..-2].each do |pane|
      pane.style.width = "#{width}px"
    end
    panes.last.style.width = "#{panes_width - (width * (panes.size - 1))}px"

    @panes = panes
    @splitters = splitters

    self.add_event_listener('mouseup'){@splitter = nil}
    self.add_event_listener('mousemove') do |ev|
      next if !@splitter || ev.buttons != 1
      i = @splitter
      d = ev.movement_x
      rect = splitters[i].get_bounding_client_rect
      next if (d > 0 && ev.x < rect.x) || (d < 0 && ev.x > rect.x + rect.width)
      h0 = panes[i].client_width + panes[i+1].client_width
      h1 = panes[i].client_width + d
      h2 = panes[i+1].client_width - d
      if h1 < 20
        h1 = 20
        h2 = h0 - 20
      end
      if h2 < 20
        h2 = 20
        h1 = h0 - 20
      end
      panes[i].style.width = "#{h1}px"
      panes[i+1].style.width = "#{h2}px"
      reset_pane_position(self.client_width)
    end

    resize_observer = JSrb.global[:ResizeObserver].new do |entries|
      entries.each do |entry|
        new_width = entry.border_box_size[0].inline_size
        reset_pane_position(new_width)
      end
      nil
    end
    resize_observer.observe(self.js_object)
  end

  def reset_pane_position(new_width)
    left = 0
    height = self.client_height
    @panes[0..-2].each_with_index do |pane, i|
      pane.style.left = "#{left}px"
      pane.style.height = "#{height}px"
      left += pane.client_width
      @splitters[i].style.left = "#{left}px"
      @splitters[i].style.height = "#{height}px"
      left += @splitters[i].client_width
    end
    @panes.last.style.left = "#{left}px"
    @panes.last.style.height = "#{height}px"
    last_pane_width = new_width - left
    last_pane_width = last_pane_width.clamp(20..)
    @panes.last.style.width = "#{last_pane_width}px"
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
        new_width = entry.border_box_size[0].inline_size
        if self.children.first
          self.children.first.style.width = "#{new_width}px"
          self.children.first.style.height = '100%'
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
    knob.class_name = 'knob'
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
