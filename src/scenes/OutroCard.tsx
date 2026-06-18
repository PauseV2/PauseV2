import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Caption } from "../components/Caption";

const FONT =
  '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif';

export const OutroCard: React.FC<{ durationInFrames: number }> = ({
  durationInFrames,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const fadeIn = interpolate(frame, [0, 14], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const titleScale = spring({ frame, fps, config: { damping: 16, mass: 0.6 } });
  const fadeOut = interpolate(
    frame,
    [durationInFrames - 24, durationInFrames],
    [1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  return (
    <AbsoluteFill
      style={{
        background: "#05060a",
        opacity: fadeIn * fadeOut,
        alignItems: "center",
        justifyContent: "center",
        flexDirection: "column",
      }}
    >
      <div
        style={{
          color: "#f1f5f9",
          fontSize: 64,
          fontWeight: 700,
          fontFamily: FONT,
          transform: `scale(${titleScale})`,
        }}
      >
        pv-govtablet
      </div>
      <div
        style={{
          marginTop: 14,
          color: "#5b9bff",
          fontSize: 26,
          fontWeight: 600,
          fontFamily: FONT,
          letterSpacing: 2,
          textTransform: "uppercase",
        }}
      >
        Built for QBCore
      </div>
      <Caption
        text="pv-govtablet. Secure. Reversible. Built for your server."
        durationInFrames={durationInFrames}
      />
    </AbsoluteFill>
  );
};
