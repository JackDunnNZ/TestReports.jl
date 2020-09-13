# Format is defined by
# https://www.ibm.com/support/knowledgecenter/en/SSQ2R2_14.2.0/com.ibm.rsar.analysis.codereview.cobol.doc/topics/cac_useresults_junit.html
# http://help.catchsoftware.com/display/ET/JUnit+Format

"""
    set_attribute!(node, attr, val)

Add the attritube with name `attr` and value `val` to `node`.
"""
set_attribute!(node, attr, val) = setindex!(node, string(val), attr)

"""
    testsuites_xml(name, id, ntests, nfails, nerrors, x_children)

Create the testsuites element of a JUnit XML.
"""
function testsuites_xml(name, id, ntests, nfails, nerrors, x_children)
    x_testsuite = ElementNode("testsuites")
    link!.(Ref(x_testsuite), x_children)
    set_attribute!(x_testsuite, "name", name)
    set_attribute!(x_testsuite, "id", id)
    set_attribute!(x_testsuite, "tests", ntests)
    set_attribute!(x_testsuite, "failures", nfails)
    set_attribute!(x_testsuite, "errors", nerrors)
    x_testsuite
end

"""
    testsuite_xml(name, id, ntests, nfails, nerrors, x_children)

Create a testsuite element of a JUnit XML.
"""
function testsuite_xml(name, id, ntests, nfails, nerrors, x_children)
    x_testsuite = ElementNode("testsuite")
    link!.(Ref(x_testsuite), x_children)
    set_attribute!(x_testsuite, "name", name)
    set_attribute!(x_testsuite, "id", id)
    set_attribute!(x_testsuite, "tests", ntests)
    set_attribute!(x_testsuite, "failures", nfails)
    set_attribute!(x_testsuite, "errors", nerrors)
    x_testsuite
end

"""
    testcase_xml(name, id, x_children)

Create a testcase element of a JUnit XML.

This is the generic form (with name, id and children) that is used by other methods.
"""
function testcase_xml(name, id, x_children)
    x_tc = ElementNode("testcase")
    link!.(Ref(x_tc), x_children)
    set_attribute!(x_tc, "name", name)
    set_attribute!(x_tc, "id", id)
    x_tc
end

"""
    testcase_xml(v::Result, childs) 

Create a testcase element of a JUnit XML for the result given by `v`.

The original expression of the test is used as the name, whilst the id is defaulted to
_testcase_id_.
"""
testcase_xml(v::Result, childs) = testcase_xml(string(v.orig_expr), "_testcase_id_", childs)

"""
    failure_xml(message, test_type, content)

Create a failure node (which will be the child of a testcase).
"""
function failure_xml(message, test_type, content)
    x_fail = ElementNode("failure")
    set_attribute!(x_fail, "message", message)
    set_attribute!(x_fail, "type", test_type)
    link!(x_fail, TextNode(content))
    x_fail
end

"""
    skip_xml()

Create a skip node (which will be the child of a testcase).
"""
function skip_xml()
    ElementNode("skip")
end

"""
    failure_xml(message, test_type, content)

Create an error node (which will be the child of a testcase).
"""
function error_xml(message, ex_type, content)
    x_fail = ElementNode("error")
    set_attribute!(x_fail, "message", message)
    set_attribute!(x_fail, "type",  ex_type)
    link!(x_fail, TextNode(content))
    x_fail
end



#####################

"""
    report(ts)

Will produce an `XMLDocument` that contains a report about the testset's results.
In theory works on many kinds of testsets.
Primarily intended for use on `ReportingTestSet`s.
"""
function report(ts::AbstractTestSet)
    total_ntests = 0
    total_nfails = 0
    total_nerrors = 0
    x_testsuites = map(ts.results) do result
        x_testsuite, ntests, nfails, nerrors = to_xml(result)
        total_ntests += ntests
        total_nfails += nfails
        total_nerrors += nerrors;
        x_testsuite
    end

    xdoc = XMLDocument()
    root = setroot!(xdoc, testsuites_xml(ts.description,
                                         "_id_",
                                         total_ntests,
                                         total_nfails,
                                         total_nerrors,
                                         x_testsuites))
    
    xdoc
end

"""
    to_xml(ts::AbstractTestSet)

Create a testsuite node from an `AbstractTestSet`, by creating nodes for each result
in `ts.results`. For creating a JUnit XML, all results must be `Result`s, that is
they cannot be `AbstractTestSet`s, as the XML cannot have one testsuite nested inside
another.
"""
function to_xml(ts::AbstractTestSet)
    total_ntests = 0
    total_nfails = 0
    total_nerrors = 0
    x_testcases = map(ts.results) do result
        x_testcase, ntests, nfails, nerrors = to_xml(result)
        total_ntests += ntests
        total_nfails += nfails
        total_nerrors += nerrors
        x_testcase
    end

    x_testsuite = testsuite_xml(ts.description, "_id_", total_ntests, total_nfails, total_nerrors, x_testcases)
    ts isa ReportingTestSet && add_testsuite_properties!(x_testsuite, ts)
    x_testsuite, total_ntests, total_nfails, total_nerrors
end

"""
    to_xml(res::Pass)
    to_xml(res::Fail)
    to_xml(res::Broken)
    to_xml(res::Error)

Create a testcase node from the result and return information on number of tests.
"""
function to_xml(res::Pass)
    x_testcase = testcase_xml("pass (info lost)", "_testcase_id_", [])
    x_testcase, 1, 0, 0  # Increment number of tests by 1
end

function to_xml(v::Fail)
    data = v.data === nothing ? "" : v.data  # Needed for V1.0
    x_failure = failure_xml(string(data), string(v.test_type), string(v))
    x_testcase = testcase_xml(v, [x_failure])
    x_testcase, 1, 1, 0  # Increment number of tests and number of failures by 1
end

function to_xml(v::Broken)
    x_testcase = testcase_xml(v, [skip_xml()]) # it is not actually skipped
    x_testcase, 0, 0, 0
end

function to_xml(v::Error)
    buff = IOBuffer()
    Base.show_backtrace(buff, scrub_backtrace(backtrace()))
    backtrace_str = String(take!(buff))

    x_testcase = error_xml(string(v.value), typeof(v.value), backtrace_str)
    x_testcase, 0, 0, 1  # Increment number of errors by 1
end

"""
    add_testsuite_properties!(x_testsuite, ts::ReportingTestSet)

Add all key value pairs in the `properties` field of a `ReportingTestSet` to the
corresponding testsuite xml element.
"""
function add_testsuite_properties!(x_testsuite, ts::ReportingTestSet)
    if !isempty(keys(ts.properties))
        x_properties = ElementNode("properties")
        for (name, value) in ts.properties
            x_property = ElementNode("property")
            set_attribute!(x_property, "name", name)
            set_attribute!(x_property, "value", value)
            link!(x_properties, x_property)
        end
        link!(x_testsuite, x_properties)
    end
    return x_testsuite
end
