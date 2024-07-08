require 'js'

# ---- JSrb
# https://mysql-params.tmtms.net/lib/jsrb.rb
JS::Object.undef_method(:then)  # JS の then を呼ぶために Ruby の then を無効化
Document = JS.global[:document]

# JS を Ruby ぽく扱えるようにする
module JSrb
  # hoge_fuga を hogeFuga に変換して JavaScript を呼び出し、
  # 値を JS::Object から Ruby に変換して返す
  def method_missing(sym, *args, &block)
    if __jsprop__(sym) == JS::Undefined
      if sym.end_with? '='
        equal = true
        sym = sym.to_s.chop.intern
      end
      if __jsprop__(sym) == JS::Undefined && sym =~ /_[a-z]/
        sym2 = sym.to_s.gsub(/_([a-z])/){$1.upcase}.intern
        if __jsprop__(sym2) == JS::Undefined
          raise NoMethodError, "undefined method `#{sym}' for #{self.inspect}"
        end
        sym = sym2
      end
    end
    v = __jsprop__(sym)
    if v.typeof == 'function'
      __convert_value__(self.call(sym, *args, &block))
    elsif !equal && args.empty?
      __convert_value__(v)
    elsif equal && args.length == 1
      self[sym] = args.first
    else
      raise NoMethodError, "undefined method `#{sym}' for #{self.inspect}"
    end
  end

  def respond_to_missing?(sym, include_private)
    return true if super
    sym2 = sym.to_s.gsub(/_([a-z])/){$1.upcase}
    __jsprop__(sym) != JS::Undefined || __jsprop__(sym2) != JS::Undefined
  end

  # @param sym [Symbol]
  # @return [Object]
  def [](sym)
    __convert_value__(super)
  end

  private

  # @param sym [Symbol]
  # @return [JS::Object]
  def __jsprop__(sym)
    self.method(:[]).super_method.call(sym.intern)
  end

  # @param v [JS::Object]
  # @return [Object]
  def __convert_value__(v)
    case v.typeof
    when 'number'
      v.to_s =~ /\./ ? v.to_f : v.to_i
    when 'bigint'
      v.to_i
    when 'string'
      v.to_s
    when 'boolean'
      v.to_s == 'true'
    else
      if v.to_s =~ /\A\[object .*(List|Collection)\]\z/
        v.length.times.map{|i| v[i]}
      elsif v == JS::Null || v == JS::Undefined
        nil
      else
        v
      end
    end
  end
end

class JS::Object
  prepend JSrb
end
# ---- JSrb

# base class for creating custom elements
class HTMLElement
  JS.eval("_ruby_htmlelement_id = 0; _ruby_htmlelement_this = {}; _attribute_changed = {}")

  def self.tag_name(name=nil)
    if name
      @tag_name = name
    elsif !@tag_name
      @tag_name = self.name.gsub(/([A-Z]+)/){"-#{$1}"}.gsub(/::/, '-').sub(/\A-/, "").downcase
    end
    @tag_name
  end

  def self.inherited(subclass)
    super
    class_name = subclass.name.gsub(/::/, '__')
    js = <<~EOS
      #{class_name} = class extends #{subclass.superclass.name.gsub(/::/, '__')} {
        constructor() {
          super()
          if (this.constructor === #{class_name}) {
            _ruby_htmlelement_id++
            _ruby_htmlelement_this[_ruby_htmlelement_id] = this
            this._ruby_htmlelement_id = _ruby_htmlelement_id
            setTimeout(()=>{rubyVM.eval('#{subclass.name}.construct('+this._ruby_htmlelement_id+')')}, 0)
          }
        }
        static get observedAttributes() { return ['hoge'] }
        connectedCallback() {
          setTimeout(()=>{rubyVM.eval('#{subclass.name}.connected_callback('+this._ruby_htmlelement_id+')')}, 0)
        }
        disconnectedCallback() {
          setTimeout(()=>{rubyVM.eval('#{subclass.name}.disconnected_callback('+this._ruby_htmlelement_id+')')}, 0)
        }
        adoptedCallback() {
          setTimeout(()=>{rubyVM.eval('#{subclass.name}.adopted_callback('+this._ruby_htmlelement_id+')')}, 0)
        }
        attributeChangedCallback(name, oldValue, newValue) {
          _attribute_changed[this._ruby_htmlelement_id] = {name, oldValue, newValue}
          setTimeout(()=>{rubyVM.eval('#{subclass.name}.attribute_changed_callback('+this._ruby_htmlelement_id+')')}, 0)
        }
      }
      customElements.define('#{subclass.tag_name}', #{class_name});
    EOS
    JS.eval(js)
  rescue JS::Error => e
    p e
    raise
  end

  def self.object
    @object ||= {}
  end

  def self.construct(id)
    obj = self.allocate
    obj.instance_variable_set(:@this, JS.global._ruby_htmlelement_this[id])
    object[id] = obj
    obj.__send__ :initialize
  end

  def self.connected_callback(id)
    object[id].connected_callback
  end

  def self.disconnected_callback(id)
    object[id].disconnected_callback
  end

  def self.adopted_callback(id)
    object[id].adopted_callback
  end

  def self.attribute_changed_callback(id)
    a = JS.global._attribute_changed[id]
    name, old_value, new_value = a.name, a.oldValue, a.newValue
    object[id].attribute_changed_callback(name, old_value, new_value)
  end

  def connected_callback
    # nothing
  end

  def disconnected_callback
    # nothing
  end

  def adopted_callback
    # nothing
  end

  def attribute_changed_callback(name, old_value, new_value)
    # nothing
  end

  def method_missing(...)
    @this.__send__(...)
  end

  def respond_to_missing?(name)
    !!@this[name]
  end
end
