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
        cursor: row-resize;
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
        width: 6px
    }
    split-splitter.horizontal {
        height: 6px
    }
  CSS
  JSrb.document.query_selector('head').append(style)

  def connected_callback
    panes = self.query_selector_all(':scope > split-pane').entries
    splitters = []
    (panes.size - 1).times.each do |i|
      splitter = JSrb.document.create_element('split-splitter')
      splitter.class_name = 'horizontal'
      splitter.add_event_listener('mousedown'){|ev| @splitter = i if ev.buttons == 1}
      splitters.push splitter
      panes[i].after splitter
    end
    splitter_height = splitters.sum(&:client_height)
    self.style.min_height = "#{(panes.size * 20) + splitter_height}px" unless self.style.min_height
    panes_height = self.client_height - splitter_height
    height = panes_height / panes.size
    panes[0..-2].each do |pane|
      pane.style.height = "#{height}px"
    end
    panes.last.style.height = "#{panes_height - (height * (panes.size - 1))}px"

    @panes = panes
    @splitters = splitters

    self.add_event_listener('mouseup'){@splitter = nil}
    self.add_event_listener('mousemove') do |ev|
      next if !@splitter || ev.buttons != 1
      i = @splitter
      d = ev.movement_y
      rect = splitters[i].get_bounding_client_rect
      next if (d > 0 && ev.y < rect.y) || (d < 0 && ev.y > rect.y + rect.height)
      h0 = panes[i].client_height + panes[i+1].client_height
      h1 = panes[i].client_height + d
      h2 = panes[i+1].client_height - d
      if h1 < 20
        h1 = 20
        h2 = h0 - 20
      end
      if h2 < 20
        h2 = 20
        h1 = h0 - 20
      end
      panes[i].style.height = "#{h1}px"
      panes[i+1].style.height = "#{h2}px"
      reset_pane_position(self.client_height)
    end

    resize_observer = JSrb.global[:ResizeObserver].new do |entries|
      entries.each do |entry|
        new_height = entry.border_box_size[0].block_size
        reset_pane_position(new_height)
      end
      nil
    end
    resize_observer.observe(self.js_object)
  end

  def reset_pane_position(new_height)
    top = 0
    width = self.client_width
    @panes[0..-2].each_with_index do |pane, i|
      pane.style.top = "#{top}px"
      pane.style.width = "#{width}px"
      top += pane.client_height
      @splitters[i].style.top = "#{top}px"
      @splitters[i].style.width = "#{width}px"
      top += @splitters[i].client_height
    end
    @panes.last.style.top = "#{top}px"
    @panes.last.style.width = "#{width}px"
    last_pane_height = new_height - top
    last_pane_height = last_pane_height.clamp(20..)
    @panes.last.style.height = "#{last_pane_height}px"
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
    self.style.width = '100%'
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
    knob.class_name = 'knob knob-horizontal'
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
