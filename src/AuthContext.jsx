import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { supabase } from './supabase';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(Boolean(supabase));

  useEffect(() => {
    if (!supabase) {
      setLoading(false);
      return undefined;
    }

    let active = true;
    let receivedAuthEvent = false;
    const restoreTimeout = window.setTimeout(() => {
      if (active) setLoading(false);
    }, 1500);
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      receivedAuthEvent = true;
      if (!active) return;
      setSession(nextSession);
      setLoading(false);
    });

    supabase.auth.getSession().then(({ data, error }) => {
      if (!active || receivedAuthEvent) return;
      setSession(error ? null : data.session);
      setLoading(false);
    }).catch(() => {
      if (active && !receivedAuthEvent) {
        setSession(null);
        setLoading(false);
      }
    });

    return () => {
      active = false;
      window.clearTimeout(restoreTimeout);
      subscription.unsubscribe();
    };
  }, []);

  const value = useMemo(() => ({
    configured: Boolean(supabase),
    loading,
    session,
    user: session?.user || null,
    signIn: async (email, password) => {
      if (!supabase) throw new Error('Customer sign-in is not configured yet.');
      const { data, error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) throw error;
      return data;
    },
    signUp: async (name, email, password) => {
      if (!supabase) throw new Error('Customer sign-in is not configured yet.');
      const emailRedirectTo = typeof window === 'undefined' ? undefined : `${window.location.origin}/`;
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { full_name: name }, ...(emailRedirectTo ? { emailRedirectTo } : {}) },
      });
      if (error) throw error;
      return data;
    },
    resendSignupConfirmation: async email => {
      if (!supabase) throw new Error('Customer sign-in is not configured yet.');
      const emailRedirectTo = typeof window === 'undefined' ? undefined : `${window.location.origin}/`;
      const { data, error } = await supabase.auth.resend({
        type: 'signup',
        email,
        options: emailRedirectTo ? { emailRedirectTo } : undefined,
      });
      if (error) throw error;
      return data;
    },
    signOut: async () => {
      if (!supabase) return;
      const { error } = await supabase.auth.signOut({ scope: 'local' });
      if (error) throw error;
    },
    updateUser: async attributes => {
      if (!supabase) throw new Error('Customer sign-in is not configured yet.');
      const { data, error } = await supabase.auth.updateUser(attributes);
      if (error) throw error;
      return data;
    },
  }), [loading, session]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used inside AuthProvider.');
  return context;
}
