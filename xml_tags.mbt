///|
priv struct XmlTag {
  name : String
  closing : Bool
  self_closing : Bool
  attributes : Map[String, String]
  input_line : Int
}

///|
priv struct XmlScanner {
  chars : Array[Char]
  mut index : Int
  mut line : Int
}

///|
fn is_xml_space(char : Char) -> Bool {
  char == ' ' || char == '\t' || char == '\r' || char == '\n'
}

///|
fn chars_to_string(chars : Array[Char], start : Int, end : Int) -> String {
  let output = StringBuilder()
  for index in start..<end {
    output.write_char(chars[index])
  }
  output.to_string()
}

///|
fn chars_have_prefix(
  chars : Array[Char],
  index : Int,
  expected : String,
) -> Bool {
  let pattern = expected.to_array()
  if index + pattern.length() > chars.length() {
    return false
  }
  for offset, char in pattern {
    if chars[index + offset] != char {
      return false
    }
  }
  true
}

///|
fn XmlScanner::advance(self : XmlScanner, count : Int) -> Unit {
  for _ in 0..<count {
    if self.index < self.chars.length() {
      if self.chars[self.index] == '\n' {
        self.line = self.line + 1
      }
      self.index = self.index + 1
    }
  }
}

///|
fn XmlScanner::skip_until(
  self : XmlScanner,
  marker : String,
  start_line : Int,
) -> Unit raise CoverageError {
  while self.index < self.chars.length() &&
        !chars_have_prefix(self.chars, self.index, marker) {
    self.advance(1)
  }
  if self.index == self.chars.length() {
    raise InvalidCobertura(
      start_line,
      "unterminated XML section; expected \{marker}",
    )
  }
  self.advance(marker.to_array().length())
}

///|
fn entity_digit(char : Char, radix : Int) -> Int? {
  let value = match char {
    '0'..='9' => char.to_int() - '0'.to_int()
    'a'..='f' => char.to_int() - 'a'.to_int() + 10
    'A'..='F' => char.to_int() - 'A'.to_int() + 10
    _ => return None
  }
  if value < radix {
    Some(value)
  } else {
    None
  }
}

///|
fn parse_numeric_entity(token : String) -> Char? {
  let chars = token.to_array()
  if chars.length() < 2 || chars[0] != '#' {
    return None
  }
  let (radix, start) = if chars.length() >= 3 &&
    (chars[1] == 'x' || chars[1] == 'X') {
    (16, 2)
  } else {
    (10, 1)
  }
  if start == chars.length() {
    return None
  }
  let mut value = 0
  for index in start..<chars.length() {
    guard entity_digit(chars[index], radix) is Some(digit) else { return None }
    value = value * radix + digit
  }
  value.to_char()
}

///|
fn decode_xml_entities(
  input : String,
  input_line : Int,
) -> String raise CoverageError {
  let chars = input.to_array()
  let output = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    if chars[index] != '&' {
      output.write_char(chars[index])
      index = index + 1
      continue
    }
    let entity_start = index + 1
    let mut end = entity_start
    while end < chars.length() && chars[end] != ';' {
      end = end + 1
    }
    if end == chars.length() {
      raise InvalidCobertura(input_line, "unterminated XML entity")
    }
    let token = chars_to_string(chars, entity_start, end)
    let decoded = match token {
      "amp" => Some('&')
      "lt" => Some('<')
      "gt" => Some('>')
      "quot" => Some('"')
      "apos" => Some('\'')
      _ => parse_numeric_entity(token)
    }
    guard decoded is Some(char) else {
      raise InvalidCobertura(input_line, "unknown XML entity &\{token};")
    }
    output.write_char(char)
    index = end + 1
  }
  output.to_string()
}

///|
fn parse_xml_tag(
  content : String,
  input_line : Int,
) -> XmlTag raise CoverageError {
  let chars = content.to_array()
  let mut index = 0
  while index < chars.length() && is_xml_space(chars[index]) {
    index = index + 1
  }
  let closing = index < chars.length() && chars[index] == '/'
  if closing {
    index = index + 1
    while index < chars.length() && is_xml_space(chars[index]) {
      index = index + 1
    }
  }
  let name_start = index
  while index < chars.length() &&
        !is_xml_space(chars[index]) &&
        chars[index] != '/' {
    index = index + 1
  }
  if name_start == index {
    raise InvalidCobertura(input_line, "XML tag name must not be empty")
  }
  let name = chars_to_string(chars, name_start, index)
  let attributes : Map[String, String] = {}
  let mut self_closing = false
  while index < chars.length() {
    while index < chars.length() && is_xml_space(chars[index]) {
      index = index + 1
    }
    if index == chars.length() {
      break
    }
    if chars[index] == '/' {
      self_closing = true
      index = index + 1
      while index < chars.length() && is_xml_space(chars[index]) {
        index = index + 1
      }
      if index != chars.length() {
        raise InvalidCobertura(
          input_line, "text follows XML self-closing slash",
        )
      }
      break
    }
    if closing {
      raise InvalidCobertura(input_line, "closing XML tag has attributes")
    }
    let attribute_start = index
    while index < chars.length() &&
          !is_xml_space(chars[index]) &&
          chars[index] != '=' &&
          chars[index] != '/' {
      index = index + 1
    }
    if attribute_start == index {
      raise InvalidCobertura(input_line, "invalid XML attribute name")
    }
    let attribute_name = chars_to_string(chars, attribute_start, index)
    while index < chars.length() && is_xml_space(chars[index]) {
      index = index + 1
    }
    if index == chars.length() || chars[index] != '=' {
      raise InvalidCobertura(
        input_line,
        "attribute \{attribute_name} is missing =",
      )
    }
    index = index + 1
    while index < chars.length() && is_xml_space(chars[index]) {
      index = index + 1
    }
    if index == chars.length() || (chars[index] != '"' && chars[index] != '\'') {
      raise InvalidCobertura(
        input_line,
        "attribute \{attribute_name} must have a quoted value",
      )
    }
    let quote = chars[index]
    index = index + 1
    let value_start = index
    while index < chars.length() && chars[index] != quote {
      index = index + 1
    }
    if index == chars.length() {
      raise InvalidCobertura(
        input_line,
        "unterminated value for attribute \{attribute_name}",
      )
    }
    let raw_value = chars_to_string(chars, value_start, index)
    attributes[attribute_name] = decode_xml_entities(raw_value, input_line)
    index = index + 1
  }
  { name, closing, self_closing, attributes, input_line }
}

///|
fn scan_xml_tags(input : String) -> Array[XmlTag] raise CoverageError {
  let scanner : XmlScanner = { chars: input.to_array(), index: 0, line: 1 }
  let tags : Array[XmlTag] = []
  while scanner.index < scanner.chars.length() {
    if scanner.chars[scanner.index] != '<' {
      scanner.advance(1)
      continue
    }
    let start_line = scanner.line
    if chars_have_prefix(scanner.chars, scanner.index, "<!--") {
      scanner.advance(4)
      scanner.skip_until("-->", start_line)
      continue
    }
    if chars_have_prefix(scanner.chars, scanner.index, "<?") {
      scanner.advance(2)
      scanner.skip_until("?>", start_line)
      continue
    }
    if chars_have_prefix(scanner.chars, scanner.index, "<![CDATA[") {
      scanner.advance(9)
      scanner.skip_until("]]>", start_line)
      continue
    }
    scanner.advance(1)
    if scanner.index < scanner.chars.length() &&
      scanner.chars[scanner.index] == '!' {
      scanner.skip_until(">", start_line)
      continue
    }
    let content_start = scanner.index
    let mut quote : Char? = None
    while scanner.index < scanner.chars.length() {
      let char = scanner.chars[scanner.index]
      match quote {
        Some(expected) => if char == expected { quote = None }
        None =>
          if char == '"' || char == '\'' {
            quote = Some(char)
          } else if char == '>' {
            break
          }
      }
      scanner.advance(1)
    }
    if scanner.index == scanner.chars.length() {
      raise InvalidCobertura(start_line, "unterminated XML tag")
    }
    let content = chars_to_string(scanner.chars, content_start, scanner.index)
    scanner.advance(1)
    tags.push(parse_xml_tag(content, start_line))
  }
  tags
}

///|
fn xml_escape_attribute(input : String) -> String {
  input
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&apos;")
}
