import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Caption } from "../components/Caption";

const FONT =
  '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif';

export const TitleCard: React.FC<{ durationInFrames: number }> = ({
  durationInFrames,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const logoScale = spring({ frame, fps, config: { damping: 14, mass: 0.6 } });
  const textOpacity = interpolate(frame, [10, 26], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const fadeOut = interpolate(
    frame,
    [durationInFrames - 14, durationInFrames],
    [1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
  const scanlineShift = (frame * 1.5) % 40;

  return (
    <AbsoluteFill style={{ background: "#05060a", opacity: fadeOut }}>
      <AbsoluteFill
        style={{
          backgroundImage:
            "repeating-linear-gradient(0deg, rgba(91,155,255,0.05) 0px, rgba(91,155,255,0.05) 1px, transparent 1px, transparent 4px)",
          backgroundPosition: `0 ${scanlineShift}px`,
        }}
      />
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          flexDirection: "column",
        }}
      >
        <div
          style={{
            width: 110,
            height: 110,
            borderRadius: 24,
            background: "#2f6fed",
            boxShadow: "0 0 60px rgba(47,111,237,0.55)",
            color: "white",
            fontSize: 44,
            fontWeight: 700,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            transform: `scale(${logoScale})`,
            fontFamily: FONT,
          }}
        >
          OT
        </div>
        <div
          style={{
            marginTop: 30,
            color: "#f1f5f9",
            fontSize: 56,
            fontWeight: 700,
            opacity: textOpacity,
            fontFamily: FONT,
            letterSpacing: 2,
          }}
        >
          GOV-OS
        </div>
        <div
          style={{
            marginTop: 6,
            color: "#64748b",
            fontSize: 22,
            opacity: textOpacity,
            fontFamily: FONT,
            letterSpacing: 4,
            textTransform: "uppercase",
          }}
        >
          Secure Terminal
        </div>
      </AbsoluteFill>
      <Caption
        text="Every government job needs more than a badge."
        durationInFrames={durationInFrames}
      />
    </AbsoluteFill>
  );
};
