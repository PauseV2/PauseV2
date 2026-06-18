import React from "react";
import { AbsoluteFill, Img, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { Caption } from "../components/Caption";

export const ImageScene: React.FC<{
  src: string;
  caption: string;
  durationInFrames: number;
  pan?: "left" | "right";
}> = ({ src, caption, durationInFrames, pan = "right" }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const fadeIn = Math.round(fps * 0.25);
  const fadeOut = Math.round(fps * 0.35);

  const opacity = interpolate(
    frame,
    [0, fadeIn, durationInFrames - fadeOut, durationInFrames],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  const scale = interpolate(frame, [0, durationInFrames], [1, 1.07], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const direction = pan === "right" ? 1 : -1;
  const translate = interpolate(frame, [0, durationInFrames], [0, 18 * direction], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const slideIn = interpolate(frame, [0, fadeIn], [24 * direction, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ background: "#15171a" }}>
      <AbsoluteFill style={{ opacity }}>
        <Img
          src={src}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            transform: `scale(${scale}) translateX(${translate + slideIn}px)`,
          }}
        />
      </AbsoluteFill>
      <Caption text={caption} durationInFrames={durationInFrames} />
    </AbsoluteFill>
  );
};
