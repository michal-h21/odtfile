kpse.set_program_name "luatex"
local zip = require "zip"
local dom = require "luaxml-domobject"
local function odtfile(filename)
  local ODT = {}
  local zipfile, errmsg = zip.open(filename, "r")
  if not zipfile then return nil, errmsg end
  ODT.filename = filename
  local schemas = {}
  ODT.zipfile = zipfile
  local contentfile = zipfile:open "content.xml"
  local content = contentfile:read("*all")
  contentfile:close()
  local contentdom = dom.parse(content)
  local used_attrs = {}
  local used_elements = {}
  local path = contentdom:get_path("office:document-content office:body office:text")
  local child = contentdom
  if path then child = path[1] end

  local buffer = {}

  local function mytraverse(el)
    local env_stack = {}
    local function add_buffer(text)
      buffer[#buffer+1]=text
    end
    local function add_command(name)
      add_buffer '\\'
      add_buffer(name)
      add_buffer "{"
    end

    local function close_command()
      add_buffer "}"
    end

    local function begin(name)
      add_command "begin"
      add_buffer(name)
      close_command()
      table.insert(env_stack, name)
    end

    local function close()
      add_command "end"
      local name = table.remove(env_stack)
      add_buffer(name)
      close_command()
    end



    local function process_children(ch)
      for _, x in ipairs(ch:get_children()) do
        mytraverse(x)
      end
    end
      
    if el:is_element() then
      local name = el:get_element_name() 
      if name == "text:p" then
        add_buffer "\n"
        process_children(el)
        add_buffer("\n\n")
      elseif name == "text:h" then
        add_buffer '\\section{'
        process_children(el)
        add_buffer "}\n"
      elseif name == "text:list" then
        begin "itemize"
        add_buffer "\n"
        process_children(el)
        close()
        add_buffer "\n"
      elseif name =="text:list-item" then
        add_buffer '\\item '
        process_children(el)
      elseif name == "text:span" then
        add_command "span"
        process_children(el)
        close_command()
      else
        add_buffer("["..name.."]")
        process_children(el)
      end
    elseif el:is_text() then
      add_buffer(el._text)
    end
  end
  mytraverse(child)
  print(table.concat(buffer))
        

  child:traverse_elements(function(el)
    local name = el:get_element_name()
    local element = used_elements[name]
    if not element then
      element = {}
      local ns, newname = name:match("(.+):(.+)") 
      element.name = newname
      element.ns = ns
      used_elements[name] = element
    end
    el._name = element.name
    el._ns = element.ns

    -- print(name, element.name, element.ns)
    for attr, value in pairs(el._attr or {}) do
      if not used_attrs[attr] then
        local schema = attr:match "xmlns:(.+)"
        if schema then
          schemas[schema] = value
        end
      end
      used_attrs[attr] = true
    end
  end)
  ODT.schemas = schemas
  -- print(contentdom:serialize(child))
  -- print(content)
end

odtfile("sample.odt")
