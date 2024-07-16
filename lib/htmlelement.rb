# ---- JSrb
require 'js'

# JS を Ruby ぽく扱えるようにする
class JSrb
  # @param obj [JS::Object]
  def initialize(obj)
    @obj = obj
  end

  # hoge_fuga を hogeFuga に変換して JavaScript を呼び出し、
  # 値を JS::Object から Ruby に変換して返す
  def method_missing(sym, *args, &block)
    jssym = sym.to_s.gsub(/_([a-z])/){$1.upcase}.intern
    if @obj[jssym] == JS::Undefined
      super unless jssym.end_with? '='
      equal = true
      jssym = jssym.to_s.chop.intern
    end
    v = @obj[jssym]
    if v.typeof == 'function'
      __convert_value__(@obj.call(jssym, *args, &block))
    elsif !equal && args.empty?
      __convert_value__(v)
    elsif equal && args.length == 1
      @obj[jssym] = args.first
    else
      super
    end
  end

  def respond_to_missing?(sym, include_private)
    return true if super
    jssym = sym.to_s.sub(/=$/, '').gsub(/_([a-z])/){$1.upcase}.intern
    @obj[sym] != JS::Undefined || @obj[jssym] != JS::Undefined
  end

  def to_s
    @obj.to_s
  end

  def to_i
    @obj.to_i
  end

  def to_h
    x = JSrb.new(JS.global[:Object].call(:entries, @obj))
    x.length.times.map.to_h{|i| [x[i][0].intern, x[i][1]]}
  end

  def inspect
    "#<JSrb: #{@obj.inspect}>"
  end

  # @param sym [Symbol]
  # @return [Object]
  def [](sym)
    __convert_value__(@obj[sym])
  end

  private

  # @param v [JS::Object]
  # @return [Object]
  def __convert_value__(v)
    return nil if v == JS::Null || v == JS::Undefined

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
      if JS.global[:Array].call(:isArray, v).to_s == 'true'
        v[:length].to_i.times.map{|i| __convert_value__(v[i])}
      elsif v[:length].typeof == 'number' && v[:item].typeof == 'function'
        v = JSrb.new(v)
        v.extend JSrb::Enumerable
        v
      else
        JSrb.new(v)
      end
    end
  end

  module Enumerable
    include ::Enumerable

    def each
      self.length.times do |i|
        yield self.item(i)
      end
    end
  end
end

$document = JSrb.new(JS.global[:document])
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
    obj.instance_variable_set(:@this, JSrb.new(JS.global[:_ruby_htmlelement_this][id]))
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
    a = JS.global[:_attribute_changed][id]
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
