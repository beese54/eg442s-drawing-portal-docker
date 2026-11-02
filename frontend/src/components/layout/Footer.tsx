/**
 * Simple footer for the EG442S containerised-application lab deployment.
 * The app shell is a fixed 100vh, so this is kept to one compact line.
 */
export function Footer() {
  return (
    <footer
      style={{
        background: '#1a3a5c',
        color: '#ffffff',
        fontSize: '0.8125rem',
        lineHeight: 1.5,
        flexShrink: 0,
        padding: '0.25rem 1.25rem',
      }}
    >
      <p style={{ margin: 0 }}>
        EG442S Lab Assignment Part 2 &middot; Containerised with Docker &middot; Deployed on AWS EC2
        &middot; Student project, not an official service
      </p>
    </footer>
  );
}
