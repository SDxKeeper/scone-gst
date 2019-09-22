import sys
import os
import glob
from zipfile import ZipFile
import logging
import urllib.request
import shutil
import hashlib
import subprocess
import json

if len(os.environ) == 0 or 'SCONE_MODE' in os.environ:
    teeMode=True
    outDir="/scone"
else:
    teeMode=False
    outDir="/iexec_out"

import gi
gi.require_version('GObject', '2.0')
gi.require_version('Gst', '1.0')
from gi.repository import Gst, GObject

input_video="/root/video-examples/Pexels_Videos_4786_960x540.mp4"
images_folder=os.path.join(outDir,"images")

def on_message(bus, message, loop):
    mtype = message.type

    if mtype == Gst.MessageType.EOS:
        print("End of stream")
        loop.quit()
    elif mtype == Gst.MessageType.ERROR:
        err, debug = message.parse_error()
        print(err, debug)
        loop.quit()
    elif mtype == Gst.MessageType.WARNING:
        err, debug = message.parse_warning()
        print(err, debug)
    return True

if __name__ == "__main__":
    print("running with following env:")
    print(os.environ)
    sys.stdout.flush()

    if teeMode:
        print("Starting in enclave")
        sys.stdout.flush()

    print(sys.argv)
    args = dict()
    if len(sys.argv) > 1:
        args = json.loads(' '.join(sys.argv[1:]))

        print("script called with arguments: ")
        print(json.dumps(args, indent=4, sort_keys=True))
        sys.stdout.flush()

    os.makedirs(images_folder, exist_ok=True)
    print("Starting gstreamer pipeline")

    pipeline_str="filesrc location=" + input_video +" ! qtdemux name=mydemux mydemux.video_0 ! \
                    decodebin ! video/x-raw ! videoconvert ! \
                    identity drop-probability=0.99 ! jpegenc ! \
                    multifilesink max-files=100 location=" + images_folder +"/image_%03d.jpg"

    print("Running gst-launch-1.0 " + pipeline_str)

    sys.stdout.flush()
    Gst.init(sys.argv)
    GObject.threads_init()

    gst_pipeline = Gst.parse_launch(pipeline_str)

    bus = gst_pipeline.get_bus()
    bus.add_signal_watch()
    loop = GObject.MainLoop()
    bus.connect("message", on_message, loop)

    gst_pipeline.set_state(Gst.State.PLAYING)
    try:
        loop.run()
    except:
        pass
    gst_pipeline.set_state(Gst.State.NULL)

    print("Finished gstreamer pipeline")

