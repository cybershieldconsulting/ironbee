class TestLuaPredicate < CLIPPTest::TestCase
  include CLIPPTest

  def make_config(lua_program, extras = {})
    return {
      modules: ['lua', 'pcre', 'htp'],
      predicate: true,
      lua_include: lua_program,
      config: "",
      default_site_config: "RuleEnable all",
    }.merge(extras)
  end

  def test_basic
    lua = <<-EOS
      Action("basic1", "1"):
        phase([[REQUEST_HEADER]]):
        action([[clipp_announce:basic1]]):
        predicate(P.Operator('rx', 'GET', P.Var('REQUEST_METHOD')))
    EOS

    clipp(make_config(lua,
      :input => "echo:\"GET /foo\""
    ))
    assert_no_issues
    assert_log_match /CLIPP ANNOUNCE: basic1/
  end

  def test_template
    lua = <<-EOS
      local getField = PUtil.Define('tc_lua_predicate_getField', {'name'},
        P.Var(P.Ref('name'))
      )
      Action("basic1", "1"):
        phase([[REQUEST_HEADER]]):
        action([[clipp_announce:basic1]]):
        predicate(P.Operator('rx', 'GET', getField('REQUEST_METHOD')))
    EOS

    clipp(make_config(lua,
      :input => "echo:\"GET /foo\""
    ))
    assert_no_issues
    assert_log_match /CLIPP ANNOUNCE: basic1/
  end

  def test_string_replace_rx
    lua = <<-EOS
      Action("basic1", "1"):
        phase([[REQUEST_HEADER]]):
        action([[clipp_announce:srr1]]):
        predicate(
          P.P(P.StringReplaceRx('a', 'b', 'bar'))
        )
    EOS

    clipp(make_config(lua,
      :input => "echo:\"GET /foo\""
    ))
    assert_no_issues
    assert_log_match /CLIPP ANNOUNCE: srr1/
    assert_log_match "'bbr'"
  end

  def test_foperator
    lua = <<-EOS
      Action("basic1", "1"):
        phase([[REQUEST_HEADER]]):
        action([[clipp_announce:foperator]]):
        predicate(P.P(P.FOperator('rx', 'a', P.Cat('a', 'ab', 'cb'))))
    EOS

    clipp(make_config(lua,
      :input => "echo:\"GET /foo\""
    ))
    assert_no_issues
    assert_log_match /CLIPP ANNOUNCE: foperator/
    assert_log_match "['a' 'ab']"
  end

  def test_genevent
    lua = <<-EOS
      Action("genevent1", "1"):
        phase("REQUEST_HEADER"):
        action("clipp_announce:foo"):
        predicate(
          P.GenEvent(
            "some/rule/id",
            1,
            "observation",
            "log",
            50,
            50,
            "Big problem",
            { "a", "b" }
          )
        )
    EOS

    clipp(make_config(lua, input: "echo:\"GET /foo\""))

    assert_no_issues
    assert_log_match 'clipp_announce(foo)'
    assert_log_match "predicate((genEvent 'some/rule/id' 1 'observation' 'log' 50 50 'Big problem' ['a' 'b']))"
  end

  def test_gen_event_expand
    lua = <<-EOS

      InitVar("MY_TYPE", "observation")
      InitVar("MY_ACTION", "log")
      InitVar("MY_SEVERITY", "50")
      InitVar("MY_CONFIDENCE", "40")
      InitVar("MY_MSG", "Big problem")

      Action("genevent1", "1"):
        phase("REQUEST"):
        action("clipp_announce:foo"):
        predicate(
          P.GenEvent(
            "some/rule/id",
            1,
            "%{MY_TYPE}",
            "%{MY_ACTION}",
            "%{MY_CONFIDENCE}",
            "%{MY_SEVERITY}",
            "%{MY_MSG}",
            { "a", "b" }
          )
        )
    EOS

    lua_module = <<-EOS
      m = ...
      m:logevent_handler(function(tx, logevent)
        print("Got logevent.")
        print("Type: "..logevent:getType())
        print("Action: "..logevent:getAction())
        print("Msg: "..logevent:getMsg())
        print("RuleId: "..logevent:getRuleId())
        print("Severity: "..logevent:getSeverity())
        print("Confidence: "..logevent:getConfidence())
        return 0
      end)

      return 0
    EOS

    clipp(make_config(lua, input: "echo:\"GET /foo\"", lua_module: lua_module))

    assert_no_issues
    assert_log_match 'clipp_announce(foo)'
    assert_log_match("Type: observation")
    assert_log_match("Action: log")
    assert_log_match("Msg: Big problem")
    assert_log_match("Severity: 50")
    assert_log_match("Confidence: 40")
    assert_log_match("Msg: Big problem")
    assert_log_match("RuleId: some/rule/id")
    # assert_log_match "predicate((genEvent 'some/rule/id' 1 'observation' 'log' 50 50 'Big problem' ['a' 'b']))"
  end
end
