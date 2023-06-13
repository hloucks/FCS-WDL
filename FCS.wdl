version 1.0

workflow RunFCS{
    input {
        File assembly
        File wrapperScript
        File adapterScript
        
        File blast_div
        File GXI
        File GXS
        File manifest
        File metaJSON
        File seq_info
        File taxa

        Int threadCount
        Int preemptible

        String GxDB = sub(GXI, "\\.gxi$", "")
        String asm_name=sub(assembly, "\\.gz$", "")
    }

    call FCSGX {
        input:
            assembly=assembly,
            wrapperScript=wrapperScript,
            adapterScript=adapterScript,
            blast_div=blast_div,
            GXI=GXI,
            GXS=GXS,
            manifest=manifest,
            metaJSON=metaJSON,
            seq_info=seq_info,
            taxa=taxa,

            GxDB=GxDB,
            asm_name=asm_name,


            preemptible=preemptible,
            threadCount=threadCount
    }

    output {
        File cleanFasta = FCSGX.cleanFasta
        File contamFasta = FCSGX.contamFasta
        File report = FCSGX.report
        File adapter_CleanedSequence = FCSGX.adapter_CleanedSequence
    }
    meta {
        author: "Hailey Loucks"
        email: "hloucks@ucsc.edu"
    }
}

task FCSGX {
    input{
        File assembly
        File wrapperScript 
        File adapterScript
        File blast_div
        File GXI
        File GXS
        File manifest
        File metaJSON
        File seq_info
        File taxa
        

        String asm_name
        String GxDB

        Int memSizeGB = 32
        Int preemptible
        Int threadCount

    }
    command <<<
        #handle potential errors and quit early
        set -o pipefail
        set -e
        set -u
        set -o xtrace

        ln -s ~{blast_div}
        ln -s ~{GXI}
        ln -s ~{GXS}
        ln -s ~{manifest}
        ln -s ~{metaJSON}
        ln -s ~{seq_info}
        ln -s ~{taxa}

        ln -s ~{assembly}
        ln -s ~{wrapperScript}
        ln -s ~{adapterScript}

        python3 ~{wrapperScript} screen genome --fasta ~{assembly} --gx-db ~{GxDB} --out-dir . --tax-id 9606
        zcat ~{assembly} | python3 ~{wrapperScript} clean genome --action-report ~{asm_name}.9606.fcs_gx_report.txt --output ~{asm_name}.clean.fasta --contam-fasta-out ~{asm_name}.contam.fasta

        # Run the adapter script 
        ~{adapterScript} --fasta-input ~{asm_name}.clean.fasta --output-dir . --euk
        mv cleaned_sequences/* ~{asm_name}.adapterClean.fa.gz

        gzip ~{asm_name}.clean.fasta
        gzip ~{asm_name}.contam.fasta
    
    >>>

    output {
        File cleanFasta = "~{asm_name}.clean.fasta.gz"
        File contamFasta = "~{asm_name}.contam.fasta.gz"
        File report = "~{asm_name}.9606.fcs_gx_report.txt"
        File adapter_CleanedSequence = "~{asm_name}.adapterClean.fa.gz"
    }

    runtime {
        memory: memSizeGB + " GB"
        preemptible : preemptible
    }
}