"use client";

// export function Providers({ children }: { children: React.ReactNode }) {
//   const [qc] = useState(() => new QueryClient());
//   return <QueryClientProvider client={qc}>{children}</QueryClientProvider>;
// }

"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";
import { AuthProvider } from "@/hooks/use-auth";

export function Providers({ children }: { children: React.ReactNode }) {
  const [qc] = useState(() => new QueryClient());
  return (
    <QueryClientProvider client={qc}>
      <AuthProvider>{children}</AuthProvider>
    </QueryClientProvider>
  );
}