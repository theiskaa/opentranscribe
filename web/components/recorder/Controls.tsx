import Glyph from "./Glyph";
import Press from "./Press";
import styles from "./Recorder.module.css";

type Props = {
  paused: boolean;
  onClose: () => void;
  onRestart: () => void;
  onTogglePause: () => void;
  onComplete: () => void;
};

export default function Controls({ paused, onClose, onRestart, onTogglePause, onComplete }: Props) {
  return (
    <div className={styles.controls}>
      <Press label="Close" className={styles.control} onTap={onClose}>
        <Glyph name="xmark" size={20} />
      </Press>
      <span className={styles.gapMd} />
      <Press label="Restart" className={styles.control} onTap={onRestart}>
        <Glyph name="arrowCounterclockwise" size={20} />
      </Press>
      <span className={styles.gapMd} />
      <Press label={paused ? "Resume" : "Pause"} className={styles.control} onTap={onTogglePause}>
        <Glyph name={paused ? "playFill" : "pauseFill"} size={20} />
      </Press>
      <span className={styles.gapXl} />
      <span className={styles.seam} />
      <span className={styles.gapXl} />
      <Press label="Done" className={`${styles.control} ${styles.complete}`} onTap={onComplete}>
        <Glyph name="checkmark" size={52 / 3} />
      </Press>
    </div>
  );
}
