import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import './styles.css';
import {
  AnimatedHeadline,
  AppIcon,
  BrandBackground,
  COLORS,
  Eyebrow,
  PhoneFrame,
  ProductFrame,
  SceneFade,
  SplitRule,
  StaggeredChips,
  VideoFill,
} from './components';

const HeaderMark: React.FC<{section: string}> = ({section}) => (
  <div
    style={{
      position: 'absolute',
      left: 180,
      right: 180,
      top: 42,
      height: 70,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      color: '#8A8A8A',
      fontFamily: 'Geist Mono',
      fontSize: 28,
      letterSpacing: 1.5,
    }}
  >
    <span>THUMBCONSOLE</span>
    <span>{section}</span>
  </div>
);

const HeroScene: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const phoneProgress = spring({frame: frame - 42, fps, config: {damping: 19, stiffness: 90, mass: 0.9}});
  const phoneY = interpolate(phoneProgress, [0, 1], [320, 0]);
  const phoneRotate = interpolate(phoneProgress, [0, 1], [-4, 0]);
  return (
    <SceneFade duration={duration} fadeOut={24}>
      <BrandBackground accent="blue" />
      <HeaderMark section="LAUNCH FILM / 2026" />
      <div style={{position: 'absolute', left: 200, top: 250}}>
        <Eyebrow color="#B3B3B3">Mac + iPhone / one controller</Eyebrow>
      </div>
      <div style={{position: 'absolute', left: 200, top: 420, zIndex: 3}}>
        <AnimatedHeadline delay={6} size={194} maxWidth={3240} lineHeight={0.94}>
          Turn your iPhone into a<br />
          <span style={{color: COLORS.blue}}>custom gaming controller.</span>
        </AnimatedHeadline>
      </div>
      <div
        style={{
          position: 'absolute',
          left: 200,
          top: 900,
          color: '#989898',
          fontSize: 54,
          lineHeight: 1.35,
          maxWidth: 1120,
        }}
      >
        Build a layout for the game. Shape every control. Keep it in your pocket.
      </div>
      <PhoneFrame
        image="captures/ios-controller-clean.png"
        width={2580}
        style={{
          position: 'absolute',
          right: -220,
          bottom: -60,
          opacity: phoneProgress,
          transform: `translateY(${phoneY}px) rotate(${phoneRotate}deg)`,
        }}
      />
      <div style={{position: 'absolute', left: 200, bottom: 130, display: 'flex', alignItems: 'center', gap: 26}}>
        <AppIcon size={100} />
        <div style={{fontSize: 44, color: '#E5E5E5', fontWeight: 500}}>ThumbConsole</div>
      </div>
    </SceneFade>
  );
};

const GenerateScene: React.FC<{duration: number}> = ({duration}) => {
  return (
    <SceneFade duration={duration}>
      <BrandBackground accent="none" />
      <HeaderMark section="01 / GENERATE" />
      <div style={{position: 'absolute', left: 180, top: 240, width: 960}}>
        <Eyebrow color={COLORS.blue}>Describe the game</Eyebrow>
        <div style={{marginTop: 70}}>
          <AnimatedHeadline delay={4} size={150} maxWidth={940} lineHeight={0.98}>
            Ask once.
            <br />Start with a complete layout.
          </AnimatedHeadline>
        </div>
        <div style={{marginTop: 78, fontSize: 48, lineHeight: 1.4, color: '#929292', maxWidth: 850}}>
          ThumbConsole’s CLI turns a game name into controls, bindings, styles, and haptics.
        </div>
        <div style={{marginTop: 70}}>
          <StaggeredChips items={['CLI', 'JSON', 'Agent-ready']} delay={35} blueIndex={2} />
        </div>
      </div>
      <ProductFrame
        width={2500}
        radius={38}
        label="TART VM / MACOS / THUMBCONSOLE CLI"
        style={{position: 'absolute', right: 150, top: 330}}
      >
        <VideoFill src="captures/mac-cli-tart.mp4" />
      </ProductFrame>
    </SceneFade>
  );
};

const BuildScene: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const zoom = interpolate(frame, [0, duration], [1, 1.015], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <SceneFade duration={duration}>
      <BrandBackground accent="blue" />
      <HeaderMark section="02 / BUILD" />
      <div style={{position: 'absolute', left: 180, top: 270, width: 1000, zIndex: 2}}>
        <Eyebrow color="#B3B3B3">A real starting point</Eyebrow>
        <div style={{marginTop: 70}}>
          <AnimatedHeadline delay={3} size={144} maxWidth={980} lineHeight={0.98}>
            Every control starts with intent.
          </AnimatedHeadline>
        </div>
        <div style={{marginTop: 70, fontSize: 48, lineHeight: 1.42, color: '#999'}}>
          Edit the device, layout, shortcuts, layers, icons, colors, and response from the Mac.
        </div>
        <div style={{marginTop: 68}}>
          <StaggeredChips items={['Arrows', 'Z', 'X', 'C', 'A']} delay={30} blueIndex={3} />
        </div>
      </div>
      <ProductFrame
        width={2520}
        radius={40}
        label="THUMBCONSOLE MAC / KEYPAD EDITOR"
        style={{position: 'absolute', right: 130, top: 250}}
      >
        <div style={{height: 1575, overflow: 'hidden'}}>
          <Img
            src={staticFile('captures/keypad-editor.png')}
            style={{width: '100%', height: '100%', objectFit: 'cover', transform: `scale(${zoom})`}}
          />
        </div>
      </ProductFrame>
    </SceneFade>
  );
};

const ControllerScene: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const p = spring({frame: frame - 8, fps, config: {damping: 17, stiffness: 95, mass: 0.9}});
  const scale = interpolate(p, [0, 1], [0.88, 1]);
  return (
    <SceneFade duration={duration}>
      <BrandBackground accent="violet" />
      <HeaderMark section="03 / PLAY" />
      <div style={{position: 'absolute', top: 205, left: 0, right: 0, textAlign: 'center'}}>
        <Eyebrow color={COLORS.blue}>Your layout, in your hands</Eyebrow>
        <div style={{marginTop: 52}}>
          <AnimatedHeadline delay={2} size={154} maxWidth={3600} align="center">
            Built for multitouch. Tuned for the game.
          </AnimatedHeadline>
        </div>
      </div>
      <PhoneFrame
        image="captures/ios-controller-clean.png"
        src="captures/ios-controller-actions.mp4"
        width={3260}
        style={{
          position: 'absolute',
          left: 290,
          top: 690,
          transform: `scale(${scale})`,
          opacity: p,
        }}
      />
      <div style={{position: 'absolute', left: 0, right: 0, top: 565}}>
        <StaggeredChips
          items={['15 controls', 'Landscape', 'Multitouch', 'Pressed states', 'Haptics']}
          delay={38}
          blueIndex={2}
          justify="center"
        />
      </div>
    </SceneFade>
  );
};

const CustomizeScene: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const callout = interpolate(frame, [92, 110], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <SceneFade duration={duration}>
      <BrandBackground accent="blue" />
      <HeaderMark section="04 / CUSTOMIZE" />
      <div style={{position: 'absolute', left: 210, top: 230, zIndex: 3}}>
        <Eyebrow color="#B7B7B7">Freeform by design</Eyebrow>
        <div style={{marginTop: 54}}>
          <AnimatedHeadline delay={2} size={160} maxWidth={3200}>
            Move it. Resize it. Make it yours.
          </AnimatedHeadline>
        </div>
      </div>
      <PhoneFrame
        image="captures/ios-controller-clean.png"
        src="captures/ios-customization.mp4"
        width={3300}
        style={{position: 'absolute', left: 270, top: 670}}
      />
      <div
        style={{
          position: 'absolute',
          right: 430,
          top: 905,
          opacity: callout,
          transform: `translateY(${(1 - callout) * 28}px)`,
          display: 'flex',
          alignItems: 'center',
          gap: 24,
        }}
      >
        <div style={{width: 150, height: 1, background: COLORS.blue}} />
        <div
          style={{
            padding: '20px 28px',
            borderRadius: 999,
            border: '1px solid rgba(72,174,255,.5)',
            background: 'rgba(0,0,0,.72)',
            color: '#C7E7FF',
            fontFamily: 'Geist Mono',
            fontSize: 30,
          }}
        >
          DRAG / SCALE / ROTATE
        </div>
      </div>
    </SceneFade>
  );
};

const SyncScene: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const line = interpolate(frame, [28, 72], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <SceneFade duration={duration}>
      <BrandBackground accent="none" />
      <HeaderMark section="05 / SYNC" />
      <div style={{position: 'absolute', left: 0, right: 0, top: 220, textAlign: 'center'}}>
        <Eyebrow color={COLORS.blue}>One local connection</Eyebrow>
        <div style={{marginTop: 50}}>
          <AnimatedHeadline delay={2} size={150} maxWidth={3600} align="center">
            Designed on Mac. Synced to iPhone.
          </AnimatedHeadline>
        </div>
      </div>
      <ProductFrame
        width={1370}
        radius={42}
        label="TART VM / THUMBCONSOLE MAC"
        style={{position: 'absolute', left: 180, top: 730}}
      >
        <VideoFill src="captures/mac-app-tart.mp4" />
      </ProductFrame>
      <div style={{position: 'absolute', left: 1570, top: 1250, width: 620, display: 'flex', alignItems: 'center'}}>
        <div style={{height: 2, width: `${line * 620}px`, background: `linear-gradient(90deg, ${COLORS.blue}, ${COLORS.violet})`}} />
        <div
          style={{
            width: 22,
            height: 22,
            marginLeft: -10,
            borderRadius: '50%',
            background: COLORS.blue,
            boxShadow: `0 0 42px ${COLORS.blue}`,
            opacity: line,
          }}
        />
      </div>
      <PhoneFrame
        image="captures/ios-controller-clean.png"
        width={1780}
        style={{position: 'absolute', right: 160, top: 900}}
      />
      <div style={{position: 'absolute', left: 0, right: 0, bottom: 105}}>
        <StaggeredChips
          items={['Local network', 'Authenticated', 'Low latency', 'Smart Connect']}
          delay={48}
          blueIndex={2}
          justify="center"
        />
      </div>
    </SceneFade>
  );
};

const OutroScene: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const p = spring({frame: frame - 4, fps, config: {damping: 16, stiffness: 100, mass: 0.8}});
  const iconScale = interpolate(p, [0, 1], [0.72, 1]);
  return (
    <SceneFade duration={duration} fadeOut={1}>
      <BrandBackground accent="blue" />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          textAlign: 'center',
          paddingTop: 310,
        }}
      >
        <AppIcon size={270} style={{transform: `scale(${iconScale})`, opacity: p}} />
        <div style={{marginTop: 80, fontSize: 184, fontWeight: 600, letterSpacing: -8, color: '#F2F2F2'}}>
          ThumbConsole
        </div>
        <div style={{marginTop: 38, fontSize: 80, color: '#B5B5B5', letterSpacing: -2}}>
          Turn your iPhone into a custom gaming controller.
        </div>
        <SplitRule style={{width: 1720, marginTop: 105}} />
        <div style={{marginTop: 90}}>
          <StaggeredChips items={['macOS + iOS', 'Build yours', 'Coming soon']} delay={22} blueIndex={1} justify="center" />
        </div>
      </div>
      <div
        style={{
          position: 'absolute',
          left: 180,
          right: 180,
          bottom: 92,
          display: 'flex',
          justifyContent: 'space-between',
          color: '#737373',
          fontFamily: 'Geist Mono',
          fontSize: 28,
          letterSpacing: 1.5,
        }}
      >
        <span>THUMBCONSOLE / LAUNCH</span>
        <span>CONTROLLER • KEYPAD • TRACKPAD</span>
      </div>
    </SceneFade>
  );
};

export const ThumbConsoleLaunch: React.FC = () => {
  return (
    <AbsoluteFill style={{backgroundColor: '#000', color: '#fff'}}>
      <Audio
        src={staticFile('music/technotronic.ogg')}
        volume={(frame) =>
          interpolate(frame, [0, 42, 1275, 1349], [0, 0.62, 0.62, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          })
        }
      />
      <Sequence from={0} durationInFrames={165}>
        <HeroScene duration={165} />
      </Sequence>
      <Sequence from={135} durationInFrames={270}>
        <GenerateScene duration={270} />
      </Sequence>
      <Sequence from={390} durationInFrames={210}>
        <BuildScene duration={210} />
      </Sequence>
      <Sequence from={570} durationInFrames={270}>
        <ControllerScene duration={270} />
      </Sequence>
      <Sequence from={810} durationInFrames={270}>
        <CustomizeScene duration={270} />
      </Sequence>
      <Sequence from={1050} durationInFrames={180}>
        <SyncScene duration={180} />
      </Sequence>
      <Sequence from={1200} durationInFrames={150}>
        <OutroScene duration={150} />
      </Sequence>
    </AbsoluteFill>
  );
};
