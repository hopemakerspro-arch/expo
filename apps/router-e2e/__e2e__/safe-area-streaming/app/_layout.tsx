import { Slot, Stack, usePathname } from 'expo-router';

export default function Layout() {
  return usePathname() === '/stack' ? <Stack screenOptions={{ headerShown: false }} /> : <Slot />;
}
