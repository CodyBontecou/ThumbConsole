import React, {CSSProperties, ReactNode} from 'react';
import {
  Easing,
  Img,
  OffthreadVideo,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

export const COLORS = {
  black: '#000000',
  ink: '#EDEDED',
  muted: '#8F8F8F',
  border: 'rgba(255,255,255,0.14)',
  borderStrong: 'rgba(255,255,255,0.26)',
  panel: '#0A0A0A',
  blue: '#48AEFF',
  blueStrong: '#006BFF',
  violet: '#746CF5',
};

export const BrandBackground: React.FC<{accent?: 'blue' | 'violet' | 'none'}> = ({
  accent = 'blue',
}) => {
  const color = accent === 'violet' ? '116,108,245' : '0,107,255';
  return (
    <div style={{position: 'absolute', inset: 0, overflow: 'hidden', background: '#000'}}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          opacity: 0.34,
          backgroundImage:
            'linear-gradient(rgba(255,255,255,.055) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,.055) 1px, transparent 1px)',
          backgroundSize: '120px 120px',
          maskImage: 'linear-gradient(to bottom, black 0%, rgba(0,0,0,.7) 58%, transparent 100%)',
        }}
      />
      {accent !== 'none' ? (
        <>
          <div
            style={{
              position: 'absolute',
              width: 2100,
              height: 1400,
              right: -700,
              top: -650,
              borderRadius: '50%',
              filter: 'blur(12px)',
              background: `radial-gradient(circle, rgba(${color},.26), rgba(${color},0) 68%)`,
            }}
          />
          <div
            style={{
              position: 'absolute',
              width: 1500,
              height: 1000,
              left: -700,
              bottom: -650,
              borderRadius: '50%',
              background: `radial-gradient(circle, rgba(${color},.14), rgba(${color},0) 70%)`,
            }}
          />
        </>
      ) : null}
      <div
        style={{
          position: 'absolute',
          left: 160,
          right: 160,
          top: 112,
          height: 1,
          background: 'rgba(255,255,255,.12)',
        }}
      />
    </div>
  );
};

export const SceneFade: React.FC<{
  duration: number;
  children: ReactNode;
  fadeIn?: number;
  fadeOut?: number;
  style?: CSSProperties;
}> = ({duration, children, fadeIn = 18, fadeOut = 18, style}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(
    frame,
    [0, fadeIn, Math.max(fadeIn + 1, duration - fadeOut), duration],
    [0, 1, 1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  return (
    <div style={{position: 'absolute', inset: 0, opacity, ...style}}>
      {children}
    </div>
  );
};

export const Eyebrow: React.FC<{children: ReactNode; color?: string}> = ({
  children,
  color = COLORS.muted,
}) => (
  <div
    style={{
      color,
      fontFamily: 'Geist Mono',
      fontSize: 42,
      fontWeight: 500,
      letterSpacing: 2.5,
      textTransform: 'uppercase',
    }}
  >
    {children}
  </div>
);

export const AnimatedHeadline: React.FC<{
  children: ReactNode;
  delay?: number;
  size?: number;
  maxWidth?: number;
  lineHeight?: number;
  align?: 'left' | 'center';
}> = ({children, delay = 0, size = 170, maxWidth = 3000, lineHeight = 0.96, align = 'left'}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const progress = spring({frame: frame - delay, fps, config: {damping: 18, stiffness: 110, mass: 0.8}});
  const y = interpolate(progress, [0, 1], [100, 0]);
  return (
    <div
      style={{
        maxWidth,
        fontSize: size,
        lineHeight,
        fontWeight: 600,
        letterSpacing: -7,
        color: COLORS.ink,
        opacity: progress,
        transform: `translateY(${y}px)`,
        textAlign: align,
      }}
    >
      {children}
    </div>
  );
};

export const Chip: React.FC<{children: ReactNode; blue?: boolean}> = ({children, blue}) => (
  <div
    style={{
      display: 'inline-flex',
      alignItems: 'center',
      minHeight: 72,
      padding: '0 28px',
      borderRadius: 999,
      border: `1px solid ${blue ? 'rgba(72,174,255,.48)' : COLORS.borderStrong}`,
      color: blue ? '#BFE2FF' : '#CFCFCF',
      background: blue ? 'rgba(0,107,255,.14)' : 'rgba(255,255,255,.045)',
      fontFamily: 'Geist Mono',
      fontSize: 34,
      whiteSpace: 'nowrap',
    }}
  >
    {children}
  </div>
);

export const ProductFrame: React.FC<{
  children: ReactNode;
  width: number;
  radius?: number;
  label?: string;
  style?: CSSProperties;
}> = ({children, width, radius = 42, label, style}) => {
  return (
    <div style={{width, ...style}}>
      {label ? (
        <div
          style={{
            marginBottom: 24,
            color: '#888',
            fontFamily: 'Geist Mono',
            fontSize: 30,
            letterSpacing: 1.5,
          }}
        >
          {label}
        </div>
      ) : null}
      <div
        style={{
          width: '100%',
          border: `2px solid ${COLORS.borderStrong}`,
          borderRadius: radius,
          overflow: 'hidden',
          background: '#050505',
          boxShadow: '0 48px 160px rgba(0,0,0,.68), 0 0 0 1px rgba(255,255,255,.04) inset',
        }}
      >
        {children}
      </div>
    </div>
  );
};

export const VideoFill: React.FC<{
  src: string;
  startFrom?: number;
  style?: CSSProperties;
}> = ({src, startFrom = 0, style}) => (
  <OffthreadVideo
    muted
    src={staticFile(src)}
    startFrom={startFrom}
    style={{display: 'block', width: '100%', height: '100%', objectFit: 'cover', ...style}}
  />
);

export const PhoneFrame: React.FC<{
  src?: string;
  image?: string;
  width?: number;
  startFrom?: number;
  style?: CSSProperties;
}> = ({src, image, width = 2940, startFrom = 0, style}) => {
  return (
    <div
      style={{
        width,
        aspectRatio: '2622 / 1206',
        padding: 30,
        borderRadius: 160,
        background: 'linear-gradient(145deg, #9EA2A7, #242629 16%, #090A0B 48%, #767A80 88%, #202225)',
        boxShadow: '0 70px 220px rgba(0,0,0,.8), 0 0 0 2px rgba(255,255,255,.32) inset',
        ...style,
      }}
    >
      <div
        style={{
          width: '100%',
          height: '100%',
          overflow: 'hidden',
          borderRadius: 128,
          background: '#050505',
          position: 'relative',
        }}
      >
        {image ? <Img src={staticFile(image)} style={{width: '100%', height: '100%', objectFit: 'cover'}} /> : null}
        {src ? (
          <VideoFill
            src={src}
            startFrom={startFrom}
            style={{position: 'absolute', inset: 0}}
          />
        ) : null}
      </div>
    </div>
  );
};

export const StaggeredChips: React.FC<{
  items: string[];
  delay?: number;
  blueIndex?: number;
  justify?: CSSProperties['justifyContent'];
}> = ({items, delay = 0, blueIndex = -1, justify = 'flex-start'}) => {
  const frame = useCurrentFrame();
  return (
    <div style={{display: 'flex', flexWrap: 'wrap', gap: 22, justifyContent: justify}}>
      {items.map((item, index) => {
        const p = interpolate(frame, [delay + index * 4, delay + index * 4 + 12], [0, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
          easing: Easing.out(Easing.cubic),
        });
        return (
          <div key={item} style={{opacity: p, transform: `translateY(${(1 - p) * 24}px)`}}>
            <Chip blue={index === blueIndex}>{item}</Chip>
          </div>
        );
      })}
    </div>
  );
};

export const AppIcon: React.FC<{size?: number; style?: CSSProperties}> = ({size = 220, style}) => (
  <Img
    src={staticFile('brand/app-icon.png')}
    style={{
      width: size,
      height: size,
      borderRadius: size * 0.22,
      boxShadow: '0 32px 90px rgba(0,0,0,.6), 0 0 0 2px rgba(255,255,255,.16)',
      ...style,
    }}
  />
);

export const SplitRule: React.FC<{style?: CSSProperties}> = ({style}) => (
  <div style={{height: 1, background: 'rgba(255,255,255,.18)', ...style}} />
);
