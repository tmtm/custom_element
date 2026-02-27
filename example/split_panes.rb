class SplitPanes < CustomElement
  style = JSrb.document.create_element('style')
  style.text_content = <<~CSS
    @property --grid-template-columns {
      syntax: "*";
      inherits: false;
    }
    @property --grid-template-rows {
      syntax: "*";
      inherits: false;
    }
    split-panes {
        display: grid;
        overflow: scroll;
        grid-template-columns: var(--grid-template-columns);
        grid-template-rows: var(--grid-template-rows);
    }
    split-pane {
        overflow: scroll;
    }
    split-splitter {
        display: flex;
        align-items: center;
        user-select: none;
        div.knob {
            user-select: none;
            z-index: 10;
        }
    }
    split-splitter.vertical {
        cursor: col-resize;
    }
    split-splitter.horizontal {
        cursor: row-resize;
    }
  CSS
  JSrb.document.query_selector('head').append(style)

  def connected_callback
    panes = self.query_selector_all(':scope > split-pane').entries

    if self.get_attribute('vertical')
      @mode = :vertical
      @dimension = :width
      @client_dimension = :clientWidth
      grid_css_param = '--grid-template-columns'
    else
      @mode = :horizontal
      @dimension = :height
      @client_dimension = :clientHeight
      grid_css_param = '--grid-template-rows'
    end

    if JSrb.window.get_computed_style(self.js_object).get_property_value(grid_css_param).empty?
      style.set_property(grid_css_param, panes.size.times.map{'1fr'}.join(' 8px '))
    end

    splitters = []
    (panes.size - 1).times.each do |i|
      splitter = JSrb.document.create_element('split-splitter')
      splitter.class_name = @mode.to_s
      splitter.add_event_listener('mousedown'){|ev| @splitter = i if ev.buttons == 1}
      splitters.push splitter
      panes[i].after splitter
    end

    @panes = panes
    @splitters = splitters

    self.add_event_listener('mouseup'){@splitter = nil}
    self.add_event_listener('mousemove') do |ev|
      next if !@splitter || ev.buttons != 1
      i = @splitter
      if @mode == :horizontal
        d = ev.movement_y
        rect = splitters[i].get_bounding_client_rect
        next if (d > 0 && ev.y < rect.y) || (d < 0 && ev.y > rect.y + rect[@dimension])
        grid_param = :gridTemplateRows
      else
        d = ev.movement_x
        rect = splitters[i].get_bounding_client_rect
        next if (d > 0 && ev.x < rect.x) || (d < 0 && ev.x > rect.x + rect[@dimension])
        grid_param = :gridTemplateColumns
      end
      grid_sizes = JSrb.window.get_computed_style(self.js_object)[grid_param].split.map(&:to_f)
      pane_sizes = grid_sizes.select.with_index{|_,i| i.even?}
      splitter_sizes = grid_sizes.select.with_index{|_,i| i.odd?}
      pane_size_total = pane_sizes[i] + pane_sizes[i+1]
      pane_sizes[i] += d
      pane_sizes[i+1] -= d
      min1 = JSrb.window.get_computed_style(panes[i]).min_width.to_f
      min2 = JSrb.window.get_computed_style(panes[i+1]).min_width.to_f
      if pane_sizes[i] < min1
        pane_sizes[i] = min1
        pane_sizes[i+1] = pane_size_total - pane_sizes[i]
      elsif pane_sizes[i+1] < min2
        pane_sizes[i+1] = min2
        pane_sizes[i] = pane_size_total - pane_sizes[i+1]
      end
      style[grid_param] = pane_sizes.zip(splitter_sizes).flatten.compact.map{"#{it}px"}.join(' ')
    end

    resize_observer = JSrb.global[:ResizeObserver].new do |entries|
      entries.each do |entry|
        box_size = entry.border_box_size[0]
        new_size = @dimension == :width ? box_size.inline_size : box_size.block_size
        # reset_pane_position(new_size)
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
