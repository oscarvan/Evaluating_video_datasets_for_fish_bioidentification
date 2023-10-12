#!/usr/bin/env nextflow

nextflow.enable.dsl=2


input_file = file('videos.txt')
path_list = input_file.readLines()  //returns the file content as a list of strings


process extractFrames {
    label "ml"

    time "1h"
    memory "2 GB"

    errorStrategy "ignore" //allows other processes to continue if error encountered
    cache "lenient"

    //publish to current Nextflow dir , with copy mode - generates output folder, using specific video file name.
    publishDir "output/${input_video.baseName}/${endFrame}/", mode: 'copy'  

    input:
        path input_video
        each endFrame
 
    output:
        path "frames"
        path "individuals"
        path "inferences"
        path "tracks"
        path "video.mp4"

    script:
    """
    /workspace/hrrsxb/.poetry/virtualenvs/morphometrics-09IGQObi-py3.11/bin/python \
        $moduleDir/../pipelines/video_tracked_and_measured_framegrabber/video_tracked_and_measured_framegrabber.py \
        -i "$input_video" \
        -o "./" \
        -fi 2 \
        -sf ${endFrame - 1000} \
        -ef ${endFrame} \
        -d 200 \
        -u 2
    """
}


process detectSpots {
    label "gpu"

    time "1h"
    memory "8 GB"

    errorStrategy "ignore" //allows other processes to continue if error encountered
    cache "lenient"

    //publish to current Nextflow dir , with copy mode - generates output folder, using specific video file name.
    publishDir "$videoOutputs/", mode: 'copy'  

    input:
        val videoOutputs
 
    output:
        path "spots/"

    script:
    """
    export PYTHONPATH=/workspace/hrrsxb/AIP/seafood-ml-models/lib/computer-vision/pfr-vision

    mkdir spots/

    /workspace/hrrsxb/AIP/seafood-ml-models/lib/computer-vision/pfr-vision/env/pytorch19/bin/python \
        /workspace/hrrsxb/AIP/seafood-ml-models/lib/computer-vision/pfr-vision/pfrvision/detectron/predict.py \
        --modelconfig /workspace/hrrsxb/AIP/seafood-ml-models/pipelines/characterise_snapperspots_underwater/output/models/complete/model_best.yml \
        --input "$videoOutputs"/individuals/ \
        --output spots/ \
        --no-labels
    """
}


workflow {
    allVideos = Channel.fromList(path_list)

    // extractFrames(
    //     allVideos,
    //     Channel.fromList((1..100).collect { it * 1000 }),
    // )

    detectSpots(Channel.fromPath("output/*/*", type: 'dir'))
}
