import Testing
@testable import SwiftCommentReflowCore

@Suite("Reflow")
struct Reflow {
    @Test func simpleReflow() {
        let a = "One line"
        let fa = a
        #expect(reflow(a) == fa)
        
        let b = """
            Two
            Lines
            """
        let fb = "Two Lines"
        #expect(reflow(b) == fb)
        
        /// white space at the end of the pre-reflowed line is ignored
        let c = ["AAA" + " ", "BBB"].joined(separator: "\n")
        let fc = "AAA BBB"
        #expect(reflow(c) == fc)

        
        let d = ["A\t","B"].joined(separator: "\n")
        let fd = "A B"
        #expect(reflow(d) == fd)

    }
    
    @Test func paragraphsAreRespected() {
        let a = """
            abc
            def
            
            pqr
            xyz
            """
        let fa = """
            abc def
            
            pqr xyz
            """
        
        #expect(reflow(a) == fa)
    }
    
    @Test func emptyLinesAtTheEndAreIgnored() {
        let a = """
            1
            2
            
            """
        let fa = """
            1 2
            """
        #expect(reflow(a) == fa)
    }
    
    @Test func whitespaceAtTheStartOfParagraphIsRespected() {
        let a = """
            aa
            
                bb
            """
        let fa = a
        #expect(reflow(a) == fa)
    }
    
    @Test func `if the next line's first non-whitespace character is a dash, then break line necessarily`() {
        let a = """
            x
            - y
            """
        let fa = a
        #expect(reflow(a) == fa)
        
        let b = """
            x
                - y
            """
        let fb = b
        #expect(reflow(b) == fb)
        
        let c = """
            x
            y-
            """
        let fc = "x y-"
        #expect(reflow(c) == fc)
        
        let d = """
            x
            
            y
            - z
            """
        let fd = d
        #expect(reflow(d) == fd)
        
        let e = """
            x
            
            - y
            """
        let fe = """
            x
            - y
            """
        #expect(reflow(e) == fe)
    }
    
    @Test func `respect markdown tables`() {
        let a = """
        | H1 | H2 |
        | --- | --- |
        | A | B |
        """
        let fa = a
        #expect(reflow(a) == fa)

        let b = """
        | H1 | H2 |
        | :--- | ---: |
        | A | B |
        """
        let fb = b
        #expect(reflow(b) == fb)

        let c = """
        intro
        | H1 | H2 |
        | --- | --- |
        | A | B |
        outro
        """
        let fc = c
        #expect(reflow(c) == fc)

        let d = """
          | A | B |
          | C | D |
        """
        let fd = d
        #expect(reflow(d) == fd)
    }

    @Test func `respect ordered lists`() {
        let a = """
        1. a
        2. b
        """
        let fa = a
        #expect(reflow(a) == fa)
        
        let b = """
        1. a
        1. b
        """
        let fb = b
        #expect(reflow(b) == fb)

        let c = """
        100. a
        500. b
        """
        let fc = c
        #expect(reflow(c) == fc)

        let d = """
          1. a
          2. b
        """
        let fd = d
        #expect(reflow(d) == fd)
    }

    @Test func `respect_lines_that_start_with_backticks`() {
        let a = """
        a
        `b
        """
        let fa = a

        #expect(reflow(a) == fa)

        let b = """
        a
          `b
        """
        let fb = b

        #expect(reflow(b) == fb)

        let c = """
        a
        ```
        b
        """
        let fc = c

        #expect(reflow(c) == fc)
    }
}


@Suite("ReflowFile")
struct ReflowFile {
    @Test func `division and reflowing`() {
        let a = """
            this
            is
            code
            
            // this
            // is
            // comment
            
            /* this
            is
            comment
            block
            */
            
            /// this
            /// is
            /// DocC
            """
        let fa1 = """
            this
            is
            code
            
            // this is comment
            
            /* this
            is
            comment
            block
            */
            
            /// this
            /// is
            /// DocC
            """
        let fa2 = """
            this
            is
            code
            
            // this
            // is
            // comment
            
            /* this is comment block
            */
            
            /// this
            /// is
            /// DocC
            """
        let fa3 = """
            this
            is
            code
            
            // this
            // is
            // comment
            
            /* this
            is
            comment
            block
            */
            
            /// this is DocC
            """
        let fa4 = """
            this
            is
            code
            
            // this is comment
            
            /* this is comment block
            */
            
            /// this is DocC
            """
        #expect(reflowFile(a, onComments: false, onCommentBlocks: false, onDocC: false) == a)
        #expect(reflowFile(a, onComments: true, onCommentBlocks: false, onDocC: false) == fa1)
        #expect(reflowFile(a, onComments: false, onCommentBlocks: true, onDocC: false) == fa2)
        #expect(reflowFile(a, onComments: false, onCommentBlocks: false, onDocC: true) == fa3)
        #expect(reflowFile(a, onComments: true, onCommentBlocks: true, onDocC: true) == fa4)
    }
    
    @Test func `multi-line comments`() {
        let a = """
            this is code // with
                         // a
                         // comment
            """
        let fa = """
            this is code // with a comment
            """
        #expect(reflowFile(a, onComments: true, onCommentBlocks: true, onDocC: true) == fa)
    }
    
    @Test func `ignore special case: header`() {
        let a = """
            // first
            // lines
            // are
            // comments
            """
        let fa = a
        #expect(reflowFile(a, onComments: true, onCommentBlocks: true, onDocC: true) == fa)
        
        let b = """
            not
            // first
            // line
            """
        let fb = """
            not
            // first line
            """
        #expect(reflowFile(b, onComments: true, onCommentBlocks: true, onDocC: true) == fb)
    }
    
    @Test func `preserve indent`() {
        let a  = """
            func a() -> Int {
                // comment
                return 32
            }
            """
        let fa = a
        #expect(reflowFile(a, onComments: true, onCommentBlocks: true, onDocC: true) == fa)
        
        let b = """
            func c() -> Int {
                // line1
                // line2
                return 33
            }
            """
        let fb = """
            func c() -> Int {
                // line1 line2
                return 33
            }
            """
        #expect(reflowFile(b, onComments: true, onCommentBlocks: true, onDocC: true) == fb)
    }
    
    @Test func `preserve context`() {
        let a = """
            this is code
            
            /// multi-line
            /// docc
            ///
            /// - Parameter param: a parameter.
            /// - Parameter param2: another parameter.
            this is code
            """
        let fa = """
            this is code
            
            /// multi-line docc
            ///
            /// - Parameter param: a parameter.
            /// - Parameter param2: another parameter.
            this is code
            """
        #expect(reflowFile(a, onComments: true, onCommentBlocks: true, onDocC: true) == fa)
        
        let b = """
            code
            // comment
            // second line
            /// docc
            /// keep docc
            code
            """
        let fb = """
            code
            // comment second line
            /// docc keep docc
            code
            """
        #expect(reflowFile(b, onComments: true, onCommentBlocks: true, onDocC: true) == fb)
        
        let c = """
            code
            // comment
            // second line
            /// docc
            ///   - keep docc
            code
            """
        let fc = """
            code
            // comment second line
            /// docc
            ///   - keep docc
            code
            """
        #expect(reflowFile(c, onComments: true, onCommentBlocks: true, onDocC: true) == fc)
        
        let d = """
            code
            
                /// docc
                /// docc
                /// - docc
                ///   - docc
            
                code
                // comment
            code
            
                /*
                 block
                 comment
                */
            """
        let fd = """
            code
            
                /// docc docc
                /// - docc
                ///   - docc
            
                code
                // comment
            code
            
                /*
                 block comment
                */
            """
        #expect(reflowFile(d, onComments: true, onCommentBlocks: true, onDocC: true) == fd)
    }
    
    @Test func `do not change the code`() {
        let a = """
            let str = "//"
            """
        #expect(reflowFile(a, onComments: true, onCommentBlocks: true, onDocC: true) == a)
        
        let b = """
            a//b
            """
        #expect(reflowFile(b, onComments: true, onCommentBlocks: true, onDocC: true) == b)
        
        let c = "/abc\\//gm"
        #expect(reflowFile(c, onComments: true, onCommentBlocks: true, onDocC: true) == c)
        
        let d = ["\"\"\"", "\t//", "\"\"\""].joined(separator: "\n")
        #expect(reflowFile(d, onComments: true, onCommentBlocks: true, onDocC: true) == d)

        let e = """
            let raw = #"https://example.com/a//b"#
            """
        #expect(reflowFile(e, onComments: true, onCommentBlocks: true, onDocC: true) == e)
    }
}
