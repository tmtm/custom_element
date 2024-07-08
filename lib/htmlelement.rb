require 'js'

# base class for creating custom elements
class HTMLElement
  JS.eval("_ruby_htmlelement_id = 0; _ruby_htmlelement_this = {}")

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
      }
      customElements.define('#{subclass.tag_name}', #{class_name});
    EOS
    JS.eval(js)
  rescue JS::Error => e
    p e
    raise
  end

  def self.construct(id)
    obj = self.allocate
    obj.instance_variable_set(:@this, JS.global[:_ruby_htmlelement_this][id])
    obj.__send__ :initialize
  end

  def method_missing(...)
    @this.__send__(...)
  end

  def respond_to_missing?(name)
    !!@this[name]
  end
end
