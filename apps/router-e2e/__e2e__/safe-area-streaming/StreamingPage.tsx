import { Suspense, use, useEffect, useState } from 'react';

const clientResource = new Promise<string>(() => {});

function createResource(delay: number) {
  // Only the server can provide this content, so client rendering cannot hide lost server DOM.
  return typeof window === 'undefined'
    ? new Promise<string>((resolve) => setTimeout(() => resolve('Streamed content'), delay))
    : clientResource;
}

function Content({ resource, id }: { resource: Promise<string>; id: string }) {
  return <p id={id}>{use(resource)}</p>;
}

function Shell() {
  useEffect(() => {
    document.documentElement.dataset.safeAreaHydrated = 'true';
  }, []);

  return (
    <button
      id="shell"
      onClick={(event) => {
        event.currentTarget.dataset.clicked = 'true';
      }}>
      Interactive shell
    </button>
  );
}

export default function StreamingPage() {
  const [resources] = useState(() => [createResource(5000), createResource(7000)]);

  return (
    <main>
      <Shell />
      <section>
        <Suspense fallback={<p id="first-fallback">First pending</p>}>
          <Content id="first" resource={resources[0]} />
        </Suspense>
        <Suspense fallback={<p id="second-fallback">Second pending</p>}>
          <Content id="second" resource={resources[1]} />
        </Suspense>
      </section>
    </main>
  );
}
