process LILAC {
    tag "${meta.id}"
    label 'process_medium'

    container 'docker.io/scwatts/lilac:1.4.2--0'

    input:
    tuple val(meta), path(normal_wgs_bam), path(normal_wgs_bai), path(tumor_wgs_bam), path(tumor_wgs_bai), path(tumor_wts_bam), path(tumor_wts_bai), path(purple_dir)
    path genome_fasta
    val genome_ver
    path lilac_resources, stageAs: 'lilac_resources'

    output:
    tuple val(meta), path('lilac/'), emit: lilac_dir
    path 'versions.yml'            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def sample_name = getSampleName(meta, tumor_wgs_bam, normal_wgs_bam)
    def tumor_wgs_bam_arg = tumor_wgs_bam ? "-tumor_bam ${tumor_wgs_bam}" : ''
    def tumor_wts_bam_arg = tumor_wts_bam ? "-rna_bam ${tumor_wts_bam}" : ''
    def purple_args = purple_dir ? """
        -gene_copy_number ${purple_dir}/${sample_name}.purple.cnv.gene.tsv \\
        -somatic_vcf ${purple_dir}/${sample_name}.purple.sv.vcf.gz \\
    """ : ''

    """
    java \\
        -Xmx${task.memory.giga}g \\
        -jar ${task.ext.jarPath} \\
            ${args} \\
            -sample ${sample_name} \\
            ${tumor_wgs_bam_arg} \\
            ${tumor_wts_bam_arg} \\
            -reference_bam ${normal_wgs_bam} \\
            -ref_genome_version ${genome_ver} \\
            -ref_genome ${genome_fasta} \\
            -resource_dir ${lilac_resources} \\
            ${purple_args.replaceAll('\\n', '')} \\
            -threads ${task.cpus} \\
            -output_dir lilac/

    # NOTE(SW): hard coded since there is no reliable way to obtain version information.
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        lilac: 1.4.2
    END_VERSIONS
    """

    stub:
    """
    mkdir -p lilac/
    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}

def getSampleName(meta, tumor_bam, normal_bam) {
    if (tumor_bam) {
        return meta.tumor_id
    } else if (normal_bam) {
        return meta.normal_id
    } else {
        Sys.exit(1)
    }
}
