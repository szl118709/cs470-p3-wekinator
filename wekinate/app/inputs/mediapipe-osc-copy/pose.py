import argparse

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.framework.formats import landmark_pb2
from pythonosc import udp_client
from pythonosc.osc_message_builder import OscMessageBuilder

from utils import add_default_args, get_video_input

OSC_ADDRESS = "/wek/inputs"


def draw_pose_rect(image, rect, color=(255, 0, 255), thickness=2):
    image_width = image.shape[1]
    image_height = image.shape[0]

    world_rect = [(rect.x_center * image_width, rect.y_center * image_height),
                  (rect.width * image_width, rect.height * image_height),
                  rect.rotation]

    box = cv2.boxPoints(world_rect)
    box = np.int0(box)
    cv2.drawContours(image, [box], 0, color, thickness)


def send_pose(client: udp_client,
              landmark_list: landmark_pb2.NormalizedLandmarkList):
    if landmark_list is None:
        client.send_message(OSC_ADDRESS, 0)
        return

    # create message and send
    builder = OscMessageBuilder(address=OSC_ADDRESS)
    builder.add_arg(1)
    for landmark in landmark_list.landmark:
        builder.add_arg(landmark.x)
        builder.add_arg(landmark.y)
        builder.add_arg(landmark.z)
        builder.add_arg(landmark.visibility)
    msg = builder.build() # 1 + 33 * 4 = 133 arguments in total
    client.send(msg)


def main():
    # read arguments
    parser = argparse.ArgumentParser()
    add_default_args(parser)
    parser.add_argument("--model-complexity", default=1, type=int,
                        help="Set model complexity (0=Light, 1=Full, 2=Heavy).")
    parser.add_argument("--no-smooth-landmarks", action="store_false", help="Disable landmark smoothing.")
    parser.add_argument("--static-image-mode", action="store_true", help="Enables static image mode.")
    args = parser.parse_args()

    # create osc client
    client = udp_client.SimpleUDPClient(args.ip, args.port, True)

    # setup camera loop
    mp_drawing = mp.solutions.drawing_utils
    mp_pose = mp.solutions.pose

    pose = mp_pose.Pose(
        smooth_landmarks=args.no_smooth_landmarks,
        static_image_mode=args.static_image_mode,
        model_complexity=args.model_complexity,
        min_detection_confidence=args.min_detection_confidence,
        min_tracking_confidence=args.min_tracking_confidence)
    cap = cv2.VideoCapture(get_video_input(args.input))

    # fix bug which occurs because draw landmarks is not adapted to upper pose
    connections = mp_pose.POSE_CONNECTIONS

    while cap.isOpened():
        success, image = cap.read()
        if not success:
            break

        # Flip the image horizontally for a later selfie-view display, and convert
        # the BGR image to RGB.
        image = cv2.cvtColor(cv2.flip(image, 1), cv2.COLOR_BGR2RGB)
        # To improve performance, optionally mark the image as not writeable to
        # pass by reference.
        image.flags.writeable = False
        results = pose.process(image)

        # send the pose over osc
        send_pose(client, results.pose_landmarks)

        if hasattr(results, "pose_rect_from_landmarks"):
            draw_pose_rect(image, results.pose_rect_from_landmarks)

        # Draw the pose annotation on the image.
        image.flags.writeable = True
        image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)

        mp_drawing.draw_landmarks(image, results.pose_landmarks, connections)
        cv2.imshow('MediaPipe OSC Pose', image)
        if cv2.waitKey(5) & 0xFF == 27:
            break
    pose.close()
    cap.release()


if __name__ == "__main__":
    main()
