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
            margin: auto;
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
      @min_size = :minWidth
      @grid_param = :gridTemplateColumns
      grid_css_param = '--grid-template-columns'
    else
      @mode = :horizontal
      @dimension = :height
      @client_dimension = :clientHeight
      @min_size = :minHeight
      @grid_param = :gridTemplateRows
      grid_css_param = '--grid-template-rows'
    end

    if JSrb.window.get_computed_style(self.js_object).get_property_value(grid_css_param).empty?
      style.set_property(grid_css_param, panes.size.times.map{'1fr'}.join(' 8px '))
    end

    splitters = []
    (panes.size - 1).times.each do |i|
      splitter = JSrb.document.create_element('split-splitter')
      splitter.class_name = @mode.to_s
      splitter.add_event_listener('mousedown'){|ev|
        if ev.buttons == 1
          @splitter = i
          @x, @y = ev.client_x, ev.client_y
        end
      }
      splitters.push splitter
      panes[i].after splitter
    end
    JSrb.timeout(0.1){
      grid_sizes = JSrb.window.get_computed_style(self.js_object)[@grid_param].split.map(&:to_f)
      style[@grid_param] = grid_sizes.map{"#{it}px"}.join(' ')
      @ready = true
    }

    @panes = panes
    @splitters = splitters

    self.add_event_listener('mouseup'){@splitter = nil}
    self.add_event_listener('mousemove') do |ev|
      next if !@splitter || ev.buttons != 1
      i = @splitter
      rect = splitters[i].get_bounding_client_rect
      dx = ev.client_x - @x
      dy = ev.client_y - @y
      @x, @y = ev.client_x, ev.client_y
      if @mode == :horizontal
        d = dy
        next if (d > 0 && ev.y < rect.y) || (d < 0 && ev.y > rect.y + rect[@dimension])
      else
        d = dx
        next if (d > 0 && ev.x < rect.x) || (d < 0 && ev.x > rect.x + rect[@dimension])
      end
      grid_sizes = JSrb.window.get_computed_style(self.js_object)[@grid_param].split.map(&:to_f)
      pane_sizes = grid_sizes.select.with_index{|_,i| i.even?}
      splitter_sizes = grid_sizes.select.with_index{|_,i| i.odd?}
      pane_size_total = pane_sizes[i] + pane_sizes[i+1]
      pane_sizes[i] += d
      pane_sizes[i+1] -= d
      min1 = JSrb.window.get_computed_style(panes[i])[@min_size].to_f
      min2 = JSrb.window.get_computed_style(panes[i+1])[@min_size].to_f
      if pane_sizes[i] < min1
        pane_sizes[i] = min1
        pane_sizes[i+1] = pane_size_total - pane_sizes[i]
      elsif pane_sizes[i+1] < min2
        pane_sizes[i+1] = min2
        pane_sizes[i] = pane_size_total - pane_sizes[i+1]
      end
      style[@grid_param] = pane_sizes.zip(splitter_sizes).flatten.compact.map{"#{it}px"}.join(' ')
    end

    resize_observer = JSrb.global[:ResizeObserver].new do |entries|
      next unless @ready
      entries.each do |entry|
        box_size = entry.border_box_size[0]
        new_size = @dimension == :width ? box_size.inline_size : box_size.block_size

        grid_sizes = JSrb.window.get_computed_style(self.js_object)[@grid_param].split.map(&:to_f)
        pane_sizes = grid_sizes.select.with_index{|_,i| i.even?}
        splitter_sizes = grid_sizes.select.with_index{|_,i| i.odd?}
        pane_size_total = grid_sizes.sum
        d = new_size - pane_size_total

        pane_sizes[-1] += d
        min = JSrb.window.get_computed_style(panes.last)[@min_size].to_f
        pane_sizes[-1] = min if pane_sizes[-1] < min
        style[@grid_param] = pane_sizes.zip(splitter_sizes).flatten.compact.map{"#{it}px"}.join(' ')
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
