import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";

export const Caption: React.FC<{ text: string; durationInFrames: number }> = ({
  text,
  durationInFrames,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const inDur = Math.round(fps * 0.4);
  const outStart = durationInFrames - Math.round(fps * 0.45);

  const opacity = interpolate(
    frame,
    [0, inDur, outStart, durationInFrames],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
  const translateY = interpolate(frame, [0, inDur], [22, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <div
      style={{
        position: "absolute",
        bottom: 70,
        left: 0,
        right: 0,
        display: "flex",
        justifyContent: "center",
        opacity,
        transform: `translateY(${translateY}px)`,
      }}
    >
      <div
        style={{
          maxWidth: "78%",
          background: "rgba(8,10,16,0.72)",
          border: "1px solid rgba(91,155,255,0.25)",
          borderRadius: 14,
          padding: "20px 40px",
          color: "#f1f5f9",
          fontSize: 34,
          fontWeight: 600,
          textAlign: "center",
          lineHeight: 1.3,
          fontFamily:
            '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
        }}
      >
        {text}
      </div>
    </div>
  );
};
